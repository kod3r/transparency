(function() {
  var ELEMENT_NODE, Transparency, elementMatcher, matchingElements, prepareContext, renderChildren, renderDirectives, renderValues, setText;

  if (typeof jQuery !== "undefined" && jQuery !== null) {
    jQuery.fn.render = function(objects, directives) {
      Transparency.render(this.get(), objects, directives);
      return this;
    };
  }

  if (typeof window !== "undefined" && window !== null) {
    window.Transparency = Transparency = {};
  }

  if (typeof module !== "undefined" && module !== null) {
    module.exports = Transparency;
  }

  Transparency.safeHtml = function(str) {
    return {
      html: str,
      safeHtml: true
    };
  };

  Transparency.render = function(contexts, objects, directives) {
    var c, context, fragment, i, isArray, n, object, parent, sibling, _i, _j, _len, _len2, _len3, _ref;
    contexts = contexts.length != null ? (function() {
      var _i, _len, _results;
      _results = [];
      for (_i = 0, _len = contexts.length; _i < _len; _i++) {
        c = contexts[_i];
        _results.push(c);
      }
      return _results;
    })() : [contexts];
    isArray = objects instanceof Array;
    if (!(objects instanceof Array)) objects = [objects];
    directives || (directives = {});
    for (_i = 0, _len = contexts.length; _i < _len; _i++) {
      context = contexts[_i];
      sibling = context.nextSibling;
      parent = context.parentNode;
      if (parent != null) parent.removeChild(context);
      prepareContext(context, objects);
      for (i = 0, _len2 = objects.length; i < _len2; i++) {
        object = objects[i];
        fragment = context.transparency.fragment;
        _ref = context.transparency.instances[i];
        for (_j = 0, _len3 = _ref.length; _j < _len3; _j++) {
          n = _ref[_j];
          fragment.appendChild(n);
          if (isArray && n.nodeType === ELEMENT_NODE) {
            n.transparency || (n.transparency = {});
            n.transparency.model = object;
          }
        }
        renderValues(fragment, object);
        renderDirectives(fragment, object, directives);
        renderChildren(fragment, object, directives);
        while (n = context.transparency.fragment.firstChild) {
          context.appendChild(n);
        }
      }
      if (sibling) {
        if (parent != null) parent.insertBefore(context, sibling);
      } else {
        if (parent != null) parent.appendChild(context);
      }
    }
    return contexts;
  };

  prepareContext = function(context, objects) {
    var n, template, _base, _base2, _base3, _base4, _results;
    context.transparency || (context.transparency = {});
    (_base = context.transparency).template || (_base.template = ((function() {
      var _results;
      _results = [];
      while (context.firstChild) {
        _results.push(context.removeChild(context.firstChild));
      }
      return _results;
    })()));
    (_base2 = context.transparency).templateCache || (_base2.templateCache = []);
    (_base3 = context.transparency).instances || (_base3.instances = []);
    (_base4 = context.transparency).fragment || (_base4.fragment = context.ownerDocument.createElement('div'));
    while (objects.length > context.transparency.instances.length) {
      template = context.transparency.templateCache.pop() || ((function() {
        var _i, _len, _ref, _results;
        _ref = context.transparency.template;
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          n = _ref[_i];
          _results.push(n.cloneNode(true));
        }
        return _results;
      })());
      context.transparency.instances.push(template);
    }
    _results = [];
    while (objects.length < context.transparency.instances.length) {
      _results.push(context.transparency.templateCache.push((function() {
        var _i, _len, _ref, _results2;
        _ref = context.transparency.instances.pop();
        _results2 = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          n = _ref[_i];
          _results2.push(context.removeChild(n));
        }
        return _results2;
      })()));
    }
    return _results;
  };

  renderValues = function(template, object) {
    var e, element, k, v, _results;
    if (typeof object === 'object') {
      _results = [];
      for (k in object) {
        v = object[k];
        if (typeof v !== 'object') {
          _results.push((function() {
            var _i, _len, _ref, _results2;
            _ref = matchingElements(template, k);
            _results2 = [];
            for (_i = 0, _len = _ref.length; _i < _len; _i++) {
              e = _ref[_i];
              _results2.push(setText(e, v));
            }
            return _results2;
          })());
        }
      }
      return _results;
    } else {
      element = matchingElements(template, 'listElement')[0] || template.getElementsByTagName('*')[0];
      if (element) return setText(element, object);
    }
  };

  renderDirectives = function(template, object, directives) {
    var attr, directive, e, key, result, _ref, _results;
    _results = [];
    for (key in directives) {
      directive = directives[key];
      if (!(typeof directive === 'function')) continue;
      _ref = key.split('@'), key = _ref[0], attr = _ref[1];
      _results.push((function() {
        var _i, _len, _ref2, _results2;
        _ref2 = matchingElements(template, key);
        _results2 = [];
        for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
          e = _ref2[_i];
          result = directive.call(object, e);
          if (attr) {
            _results2.push(e.setAttribute(attr, result));
          } else {
            _results2.push(setText(e, result));
          }
        }
        return _results2;
      })());
    }
    return _results;
  };

  renderChildren = function(template, object, directives) {
    var k, v, _results;
    _results = [];
    for (k in object) {
      v = object[k];
      if (typeof v === 'object') {
        _results.push(Transparency.render(matchingElements(template, k), v, directives[k]));
      }
    }
    return _results;
  };

  setText = function(e, text) {
    var c, children, _i, _len, _ref, _results;
    if ((e != null ? (_ref = e.transparency) != null ? _ref.text : void 0 : void 0) === text) {
      return;
    }
    e.transparency || (e.transparency = {});
    e.transparency.text = text;
    children = filter((function(n) {
      return n.nodeType === ELEMENT_NODE;
    }), e.childNodes);
    while (e.firstChild) {
      e.removeChild(e.firstChild);
    }
    if (text.safeHtml) {
      e.innerHTML = text.html;
    } else {
      e.appendChild(e.ownerDocument.createTextNode(text));
    }
    _results = [];
    for (_i = 0, _len = children.length; _i < _len; _i++) {
      c = children[_i];
      _results.push(e.appendChild(c));
    }
    return _results;
  };

  matchingElements = function(template, key) {
    var firstChild, _base, _base2;
    if (!(firstChild = template.firstChild)) return [];
    firstChild.transparency || (firstChild.transparency = {});
    (_base = firstChild.transparency).queryCache || (_base.queryCache = {});
    return (_base2 = firstChild.transparency.queryCache)[key] || (_base2[key] = template.querySelectorAll ? template.querySelectorAll("#" + key + ", " + key + ", ." + key + ", [data-bind='" + key + "']") : filter(elementMatcher(key), template.getElementsByTagName('*')));
  };

  elementMatcher = function(key) {
    return function(element) {
      return element.className.indexOf(key) > -1 || element.id === key || element.tagName.toLowerCase() === key.toLowerCase() || element.getAttribute('data-bind') === key;
    };
  };

  ELEMENT_NODE = 1;

  if (typeof filter === "undefined" || filter === null) {
    filter = function(p, xs) {
      var x, _i, _len, _results;
      _results = [];
      for (_i = 0, _len = xs.length; _i < _len; _i++) {
        x = xs[_i];
        if (p(x)) _results.push(x);
      }
      return _results;
    };
  }

}).call(this);