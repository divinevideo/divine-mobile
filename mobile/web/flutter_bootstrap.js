// Serve CanvasKit from the same origin (already deployed under /canvaskit/
// with immutable cache headers) so cold start reuses the app's existing HTTP/3
// connection instead of opening a third-party connection to www.gstatic.com.
{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: {
    canvasKitBaseUrl: 'canvaskit/',
  },
});
