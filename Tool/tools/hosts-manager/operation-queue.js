export function createOperationQueue(onPendingChange = () => {}) {
  let tail = Promise.resolve();
  let pending = 0;

  const run = (operation) => {
    const execute = async () => {
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
