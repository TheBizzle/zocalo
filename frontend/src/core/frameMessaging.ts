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

// If `willWait` is `false`, just sends async.  Otherwise, treats the oldest request for which `isReply`
// is `true` as the corresponding message. --Jason B. (10/25/26)
type CommsSender = (m: object, willWait: boolean, isReply?: (msg: object) => boolean) => Promise<object>;

function makeCommsChannel(): [MessagePort, CommsSender] {

  const { port1: myPort, port2: theirPort } = new MessageChannel();

  type Waiter = { readonly isReply: (msg: object) => boolean, readonly resolve: (msg: object) => void };
  const waiters: Array<Waiter> = [];

  myPort.onmessage = (response: MessageEvent<object>): void => {
    const index = waiters.findIndex((waiter) => waiter.isReply(response.data));
    if (index >= 0) {
      const [waiter] = waiters.splice(index, 1);
      waiter!.resolve(response.data);
    }
  };

  const sender: CommsSender =
    async (message, willWait, isReply = (_msg: object): boolean => true) => {
      if (!willWait) {
        myPort.postMessage(message);
        return {};
      } else {
        return new Promise(
          (resolve, reject) => {
            const timer =
              setTimeout(
                () => {
                  waiters.splice(waiters.indexOf(waiter), 1);
                  reject(new Error("Comms channel timed out"));
                }
              , 5000
              );
            const waiter = { isReply, resolve: (m: object): void => { clearTimeout(timer); resolve(m); } };
            waiters.push(waiter);
            myPort.postMessage(message);
          }
        );
      }
    };

  return [theirPort, sender];

}

export { makeCommsChannel, sendAMessage, sendForAReply };
