// Auto-boot SuperDirt on sclang start
(
Server.killAll;
s.options.numBuffers = 1024 * 256;
s.options.memSize = 8192 * 64;
s.options.numWireBufs = 2048;
s.options.maxNodes = 1024 * 64;
s.options.memoryLocking = true;
s.latency = 0.1;
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
