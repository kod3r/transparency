# Adapted from https://github.com/umdjs/umd
((root, factory) ->
  # AMD
  if define?.amd then define factory

  # Node.js
  else if module?.exports
    module.exports = factory()

  # Browser global
  else root.Transparency = factory()

) this, () ->

  register = ($) ->
    $?.fn.render = (models, directives, config) ->
      render context, models, directives, config for context in this
      this

  $ = @jQuery || @Zepto
  register $

  expando = 'transparency'
  data    = (element) ->
    # Expanding DOM element with a JS object is generally unsafe.
    # However, as references to expanded DOM elements are never lost, no memory leaks are introduced
    # http://perfectionkills.com/whats-wrong-with-extending-the-dom/
    element[expando] ||= {}

  nullLogger    = () ->
  consoleLogger = (messages...) -> console.log messages...
  log           = nullLogger

  render = (context, models, directives, config) ->
    log = if config?.debug and console? then consoleLogger else nullLogger
    log "Context:", context, "Models:", models, "Directives:", directives, "Config:", config
    return unless context

    models     ||= []
    directives ||= {}
    models       = [models] unless isArray models

    # DOM manipulation is a lot faster when elements are detached.
    # Save the original position, so we can put the context back to it's place.
    parent = context.parentNode
    if parent
      sibling = context.nextSibling
      parent.removeChild context

    # Make sure we have right amount of template instances available
    prepareContext context, models

    # Render each model to its template instance
    contextData = data context
    for model, index in models
      children  = []
      instance  = contextData.instances[index]
      log "Model:", model, "Template instance for the model:", instance

      # Associate model with instance elements
      data(e).model = model for e in instance.elements

      # Render values
      if isDomElement(model) and element = instance.elements[0]
        empty(element).appendChild model

      else if typeof model == 'object'
        for own key, value of model when value?

          if isPlainValue value
            for element in matchingElements instance, key

              nodeName = element.nodeName.toLowerCase()
              if nodeName == 'input'
                attr element, 'value', value
              else if nodeName == 'select'
                attr element, 'selected', value
              else attr element, 'text',  value

          else if typeof value == 'object'
            children.push key

      # Render directives
      renderDirectives instance, model, index, directives

      # Render children
      for key in children
        for element in matchingElements instance, key
          render element, model[key], directives[key], config

    # Finally, put the context element back to its original place in DOM
    if parent
      if sibling
      then parent.insertBefore context, sibling
      else parent.appendChild context

    # Return the context to support jQuery-like chaining
    context

  prepareContext = (context, models) ->
    contextData = data context

    # Initialize context
    unless contextData.template
      contextData.template      = cloneNode context
      contextData.instanceCache = [] # Query-cached template instances are precious, save them for the future
      contextData.instances     = [new Instance(context)] # Currently used template instances
    log "Template", contextData.template

    # Get templates from the cache or clone new ones, if the cache is empty.
    while models.length > contextData.instances.length
      instance = contextData.instanceCache.pop() || new Instance(cloneNode contextData.template)
      (context.appendChild n for n in instance.childNodes)
      contextData.instances.push instance

    # Remove leftover templates from DOM and save them to the cache for later use.
    while models.length < contextData.instances.length
      contextData.instanceCache.push instance = contextData.instances.pop()
      (n.parentNode.removeChild n) for n in instance.childNodes

    # Reset templates before reuse
    for instance in contextData.instances
      for element in instance.elements
        for attribute, value of data(element).originalAttributes
          attr element, attribute, value

  class Instance
    constructor: (@template) ->
      @queryCache = {}
      @elements   = []
      @childNodes = []
      getElementsAndChildNodes @template, @elements, @childNodes

  getElementsAndChildNodes = (template, elements, childNodes) ->
    child = template.firstChild
    while child
      childNodes?.push child

      if child.nodeType == ELEMENT_NODE
        data(child).originalAttributes ||= {}
        elements.push child
        getElementsAndChildNodes child, elements

      child = child.nextSibling

  renderDirectives = (instance, model, index, directives) ->
    return unless directives
    model = if typeof model == 'object' then model else value: model

    for own key, attributes of directives when typeof attributes == 'object'
      for element in matchingElements instance, key
        for attribute, directive of attributes when typeof directive == 'function'

          value = directive.call model, element: element, index: index, value: attr element, attribute
          attr element, attribute, value

  setHtml = (element, html) ->
    elementData = data element
    return if elementData.html == html

    elementData.html       = html
    elementData.children ||= (n for n in element.childNodes when n.nodeType == ELEMENT_NODE)

    empty element
    element.innerHTML = html
    element.appendChild child for child in elementData.children

  setText = (element, text) ->
    elementData = data element
    return if !text? or elementData.text == text

    elementData.text = text
    textNode         = element.firstChild

    if !textNode
      element.appendChild element.ownerDocument.createTextNode text

    else if textNode.nodeType != TEXT_NODE
      element.insertBefore element.ownerDocument.createTextNode(text), textNode

    else
      textNode.nodeValue = text

  getText = (element) ->
    (child.nodeValue for child in element.childNodes when child.nodeType == TEXT_NODE).join ''

  setSelected = (element, value) ->
    childElements = []
    getElementsAndChildNodes element, childElements
    for child in childElements
      if child.nodeName.toLowerCase() == 'option'
        if child.value == value
          child.selected = true
        else
          child.selected = false

  attr = (element, attribute, value) ->
    elementData = data element

    if element.nodeName.toLowerCase() == 'select' and attribute == 'selected'
      value = value.toString() if value? and typeof value != 'string'
      setSelected(element, value) if value?

    else switch attribute

      when 'text'
        unless isVoidElement element
          value = value.toString() if value? and typeof value != 'string'
          elementData.originalAttributes['text'] ?= getText element
          setText(element, value) if value?

      when 'html'
        value = value.toString() if value? and typeof value != 'string'
        elementData.originalAttributes['html'] ?= element.innerHTML
        setHtml(element, value) if value?

      when 'class'
        elementData.originalAttributes['class'] ?= element.className
        element.className = value if value?

      else
        if value?
          element[attribute] = value
          if isBoolean value
            elementData.originalAttributes[attribute] ?= element.getAttribute(attribute) || false
            if value
              element.setAttribute attribute, attribute
            else
              element.removeAttribute attribute
          else
            elementData.originalAttributes[attribute] ?= element.getAttribute(attribute) || ""
            element.setAttribute attribute, value.toString()


    if value? then value else elementData.originalAttributes[attribute]

  matchingElements = (instance, key) ->
    elements = instance.queryCache[key] ||= (e for e in instance.elements when exports.matcher e, key)
    log "Matching elements for '#{key}':", elements
    elements

  matcher = (element, key) ->
    element.id                        == key        ||
    indexOf(element.className.split(' '), key) > -1 ||
    element.name                      == key        ||
    element.getAttribute('data-bind') == key

  clone = (node) -> $(node).clone()[0]

  empty = (element) ->
    element.removeChild child while child = element.firstChild
    element

  ELEMENT_NODE  = 1
  TEXT_NODE     = 3

  # From http://www.w3.org/TR/html-markup/syntax.html: void elements in HTML
  VOID_ELEMENTS = ["area", "base", "br", "col", "command", "embed", "hr", "img", "input", "keygen", "link", "meta", "param", "source", "track", "wbr"]

  # IE8 <= fails to clone detached nodes properly, shim with jQuery
  # jQuery.clone: https://github.com/jquery/jquery/blob/master/src/manipulation.js#L594
  # jQuery.support.html5Clone: https://github.com/jquery/jquery/blob/master/src/support.js#L83
  html5Clone = () -> document.createElement("nav").cloneNode(true).outerHTML != "<:nav></:nav>"
  cloneNode  =
    if not document? or html5Clone()
      (node) -> node.cloneNode true
    else
      (node) ->
        cloned = clone(node)
        if cloned.nodeType == ELEMENT_NODE
          cloned.removeAttribute expando
          (element.removeAttribute expando) for element in cloned.getElementsByTagName '*'
        cloned

  # Mostly from https://github.com/documentcloud/underscore/blob/master/underscore.js
  toString      = Object.prototype.toString
  isDate        = (obj) -> toString.call(obj) == '[object Date]'
  isDomElement  = (obj) -> obj.nodeType == ELEMENT_NODE
  isVoidElement = (el)  -> indexOf(VOID_ELEMENTS, el.nodeName.toLowerCase()) > -1
  isPlainValue  = (obj) -> isDate(obj) or typeof obj != 'object' and typeof obj != 'function'
  isBoolean     = (obj) -> obj is true or obj is false
  isArray       = Array.isArray || (obj) -> toString.call(obj) == '[object Array]'
  indexOf       = (array, item) ->
    return array.indexOf(item) if array.indexOf
    for x, i in array
      if x == item then return i
    -1

  # Return module exports
  exports =
    render:    render
    register:  register
    matcher:   matcher
    clone:     clone
