module sound.consts;

import timing;

/// Internal collection of useful constants for dealing with audio

package {

    /// The maximum volume value
    const MAX_VOLUME = 15 /* max 4 bit val */;

    /// The maximum frequency value
    const MAX_FREQUENCY = 2047 /* max 11 bit val */;

    // TODO verify
    immutable bool[8][4] dutyCycles = [
        [false, false, false, true, false, false, false], // 12.5%
        [false, false, true, true, false, false, false, false], // 25%
        [false, false, true, true, true, true, false, false], // 50%
        [true, true, false, false, true, true, true, true], // 75%
    ];

}