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

function makeCommsChannel(): [MessagePort, (m: object, willWait: boolean) => Promise<object>] {

  const { port1: myPort, port2: theirPort } = new MessageChannel();

  const sender =
    async (message: object, willWait: boolean): Promise<object> => {
      return new Promise(
        (resolve, reject) => {
          myPort.onmessage = (response: MessageEvent<object>): void => {
            resolve(response.data);
          };
          myPort.postMessage(message);
          if (willWait) {
            setTimeout(
              () => { reject(new Error("Comms channel timed out")); }
            , 5000
            );
          }
        }
      );
    };

  return [theirPort, sender];

}

export { makeCommsChannel, sendAMessage, sendForAReply };
