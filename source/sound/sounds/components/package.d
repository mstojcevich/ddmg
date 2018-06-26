module sound.sounds.components;

public import sound.sounds.components.envelope;
public import sound.sounds.components.sweep;

/*
 * There are several "traits"/"components" shared across
 * the different sounds of the GameBoy, such as "envelope"
 * and "sweep".
 * This package is in place to reduce the amount
 * of repeated logic in each sound implementation.
 */
