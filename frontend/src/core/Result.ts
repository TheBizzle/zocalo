class Success<T> implements ResultInterface<T> {

  public readonly isOK = true as const;
  public constructor(public value: T) {}

  public fold<U>(_: (error: Error) => U, ifSucceeded: (value: T) => U): U {
    return ifSucceeded(this.value);
  }

}

class Failure implements ResultInterface<never> {

  public readonly isOK = false as const;
  public constructor(public error: Error) {}

  public fold<U>(ifFailed: (error: Error) => U, _: (value: never) => U): U {
    return ifFailed(this.error);
  }

}

type ResultInterface<T> = {
  readonly isOK: boolean
  fold: <U>(ifFailed: (error: Error) => U, ifSucceeded: (value: T) => U) => U
}

type Result<T> = Success<T> | Failure;

export { Failure, type Result, Success };
