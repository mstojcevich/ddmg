module sound.frontend;

interface SoundFrontend {

    /// Play the specified audio. Should represent 1/4,194,304th of a second worth of audio
    @safe void playAudio(ubyte left, ubyte right);

}