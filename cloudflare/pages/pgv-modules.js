// pgv-modules.js — Module frontend assets loader
// Loads JS/CSS for modules that have custom Alpine components

(function() {
  var modules = {
    ops: { js: '/ops.js', css: '/ops.css' }
  };

  // Load when navigating to a module
  var loaded = {};
  document.addEventListener('alpine:init', function() {
    // Observe URL changes and load module assets
    var check = function() {
      var schema = location.pathname.split('/')[1];
      if (schema && modules[schema] && !loaded[schema]) {
        loaded[schema] = true;
        var m = modules[schema];
        if (m.css) {
          var link = document.createElement('link');
          link.rel = 'stylesheet';
          link.href = m.css;
          document.head.appendChild(link);
        }
        if (m.js) {
          var script = document.createElement('script');
          script.src = m.js;
          document.head.appendChild(script);
        }
      }
    };
    check();
    // Also check on navigation
    var origPush = history.pushState;
    history.pushState = function() {
      origPush.apply(history, arguments);
      setTimeout(check, 50);
    };
    window.addEventListener('popstate', check);
  });
})();
