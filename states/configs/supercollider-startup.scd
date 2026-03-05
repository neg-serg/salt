// Auto-boot SuperDirt on sclang start
// Deployed by Salt — edits will be overwritten
(
s.reboot {
    s.waitForBoot {
        ~dirt = SuperDirt(2, s);
        ~dirt.loadSoundFiles;
        s.sync;
        ~dirt.start(57120, 0 ! 12);  // 12 orbits on port 57120
        "*** SuperDirt started ***".postln;
    };
};
)
