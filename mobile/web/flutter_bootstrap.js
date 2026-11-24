// Serve CanvasKit from the same origin so cold start reuses the app's existing
// HTTP/3 connection instead of opening a third-party connection to
// www.gstatic.com. Local builds use unversioned 'canvaskit/'; CI and deploy
// workflows run scripts/version_web_canvaskit.sh to relocate files under
// canvaskit/<engineRevision>/ and rewrite canvasKitBaseUrl so immutable
// /canvaskit/* headers stay version-pinned across Flutter upgrades.
{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: {
    canvasKitBaseUrl: 'canvaskit/',
  },
});
