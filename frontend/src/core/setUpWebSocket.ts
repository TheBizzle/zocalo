async function setUpWebSocket(urlNoProtocol: string, onMessage: (e: MessageEvent<string>) => void):
  Promise<void> {

  const protocol = window.location.protocol === "https:" ? "wss" : "ws";
  const domain   = window.location.host;
  const prefix   = `${protocol}://${domain}`;

  const socket = new WebSocket(`${prefix}${urlNoProtocol}`);

  socket.onmessage = onMessage;

  socket.onerror = (event): void => {
    console.error("Socket error", event);
  };

  socket.onclose = (event): void => {
    console.warn("Socket unexpected closed", event.code, event.reason);
  };

}

export { setUpWebSocket };
