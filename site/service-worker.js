// Retire the service worker installed when this hostname served Immich.
// Oqta is a static site and does not need an offline application worker.
self.addEventListener("install", () => self.skipWaiting());
self.addEventListener("activate", (event) => {
  event.waitUntil((async () => {
    await self.registration.unregister();
    const windows = await self.clients.matchAll({ type: "window" });
    await Promise.all(windows.map((client) => {
      const url = new URL(client.url);
      if (url.origin === self.location.origin &&
          (url.pathname === "/auth/login" || url.pathname === "/auth/login/")) {
        return client.navigate("/");
      }
      return Promise.resolve();
    }));
  })());
});
