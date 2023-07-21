/**
 * Getting a random number between two values
 *
 * @example
 * getRandomRange(1, 5)
 * // returns 3
 * getRandomRange(1, 5)
 * // returns 5
 * @param {number} min
 * @param {number} max
 * @returns
 */
export function randomRange(min: number, max: number) {
  return Math.floor(Math.random() * (max - min)) + min;
}

/**
 * Getting a random numbers between two values
 * @param {number} numbers
 * @param {number} min
 * @param {number} max
 * @returns
 */
export function bulkRandomRange(numbers: number, min: number, max: number) {
  const randomNumbers: number[] = [];
  // eslint-disable-next-line
  while (true) {
    const randomNumber = randomRange(min, max);
    if (randomNumbers.includes(randomNumber)) {
      continue;
    } else {
      randomNumbers.push(randomNumber);
    }

    if (randomNumbers.length >= numbers) {
      break;
    }
  }
  return randomNumbers;
}
