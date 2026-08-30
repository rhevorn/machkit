export type OperationQueue = {
  run: <T>(operation: () => Promise<T> | T) => Promise<T>;
  pending: () => number;
};

export function createOperationQueue(
  onPendingChange: (pending: number) => void = () => {},
): OperationQueue {
  let tail: Promise<unknown> = Promise.resolve();
  let pending = 0;

  const run = <T,>(operation: () => Promise<T> | T): Promise<T> => {
    const execute = async (): Promise<T> => {
      pending += 1;
      onPendingChange(pending);
      try {
        return await operation();
      } finally {
        pending -= 1;
        onPendingChange(pending);
      }
    };
    const result = tail.then(execute, execute);
    tail = result.catch(() => undefined);
    return result;
  };

  return { run, pending: () => pending };
}
