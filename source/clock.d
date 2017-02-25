/**
 * Keeps track of how many cycles have elapsed
 */
struct Clock {
    // TODO research why there are two types of ticks

    /** M-ticks elapsed */
    uint m;

    /** T-ticks elapsed */
    uint t;
}