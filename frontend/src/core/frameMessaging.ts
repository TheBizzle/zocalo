function sendAMessage(cond: () => boolean, sendIt: (m: object) => void): (m: object) => Promise<void> {

  const promise =
    new Promise(
      (resolve) => {
        const check = (): void => {
          if (cond()) {
            resolve(true);
          } else {
            setTimeout(check, 50);
          }
        };
        check();
      }
    );

  return async (message: object) => {
    await promise;
    sendIt(message);
  };

}

function sendForAReply( cond: () => boolean
                      , sendIt: (m: object, port: MessagePort) => void
                      ): (m: object) => Promise<object> {

  const promise =
    new Promise(
      (resolve) => {
        const check = (): void => {
          if (cond()) {
            resolve(true);
          } else {
            setTimeout(check, 50);
          }
        };
        check();
      }
    );

  return async (message: object) => {

    await promise;

    return new Promise(
      (resolve, reject) => {

        const channel = new MessageChannel();

        channel.port1.onmessage = (response: MessageEvent<object>): void => {
          resolve(response.data);
          channel.port1.close();
        };

        sendIt(message, channel.port2);

        setTimeout(
          () => {
            reject(new Error("Walkie talkie timed out"));
            channel.port1.close();
          }
        , 5000
        );

      }
    );

  };

}

export { sendAMessage, sendForAReply };
