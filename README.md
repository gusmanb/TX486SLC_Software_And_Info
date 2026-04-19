# TX486SLC info and software

Lately a batch of TX486SLC have appeared in AliExpress. These are clones of the Cyrix 486SL/C that are really good for upgrading very old 386SX motherboards, and as I have one of these laying around I decided to get a couple of them just to test if they were even real.

It happens that they are, they seem to be NOS, not sure where they come from but they are 100% legit.

After replacing the CPU on my board I found that all the software laying around is for the Cyrix and that it does not work at all with the TX, so after getting the manual of these CPUs I made my own software to be able to configure the internal cache (this is the biggest improvement against the 386SX) and also implemented all the required mods to get it working at maximum speed.

As there is not much practical info about it beyond the CPU manual I decided to upload everything to this repo hoping that this may help others embarked in the same adventure ;)

All software in the repository was compiled with TASM 5.0 under MS-DOS 6.22.

## TI_CACHE.COM

This is the first program that I have created, is a command line tool to configure the cache. The usage is very simple, through params you can control all the bits of the CCR0 register and the caching of shadow BIOS areas.

Before configuring anything I recommend you to read the reference guide in the documents section to understand what it does. Use /h to see all the available options, or /q for the best performance (but keep in mind, it may require the full hardware mods to be implemented).

The full list of options is this:


* CCR0 settings
  
|Switch|Action|
|-|-|
|/M|Disable caching of 1MB boundaries (64KB)|
|/U|Disable caching of upper memory (640-1MB)|
|/A|Enable A20M signal|
|/K|Enable KEN signal|
|/F|Enable FLUSH signal|
|/B|Enable BARB (flush cache during hold)|
|/D|Set cache to direct mapping|
|/S|Enable suspend signals|

* CCR1 settings
  
|Switch|Action|
|-|-|
|/C|Enable caching of shadow BIOS area (C0000h)|
|/Q|Quick settings (A20M + FLUSH + Shadow)|


As a quick guide, if you do NOT want to do the mods, remember to enable NC0 and BARB, that will enable the cache without needing to modify anything.

My knowledge of x86 assembler is (well... was, now I understand a bit xD) literally zero, this is the first time I have used it, so if you find dirty awful code, don't get surprised :D

## CACHEBM.COM

This is a little program to measure the cache performance. All other programs I have tested cannot check the speed (SpedSys gets hung with this CPU as it tries to identify it as a Cyrix and some registers are different and CACHECHK does not see it, not sure why). This tests the difference in tick clocks between cached and uncached areas (the TX486SLC has 1KB of cache). It is in spanish, but the info is mostly universal to be understood ;)

DISCLAIMER: this tool was made with AI and then tweaked by me, so expect awful code.

## Hardware mods

This is the part that took me most time, to understand what and how to properly connect everything in the motherboard. There are some settings that can be used to enable the cache without any hardware mods, but the performance degradation vs. all the mods installed is abysmal.

In my case, the original 386SX/20 was able to reach around 6FPS in Superscape 3DBench and clocked like an AT machine at 30Mhz in Landmark. With the new CPU, no mods and the cache using BARB and NC0 it got 9FPS and clocked like a 44Mhz AT machine. With the full mods the numbers skyrocket, it got to 14FPS and clocked like a 104Mhz machine!

So, what do these mods and how to install them?

This is the full schematic, but please, read the next sections to understand why and how to apply these.
![Schematic](https://github.com/gusmanb/TX486SLC_Software_And_Info/blob/main/Docs/Mods%20Schematic.png?raw=true)

The NAND gates are a single 74LS00, two of the four gates are used (remeber also to power it!)

### The /FLUSH mod

To invalidate the cache, the TX486SLC implements an input called /FLUSH, this input must be active whenever data changes without the CPU doing it actively, for example with a DMA transfer from the floppy or the hard disk. The cache can be invalidated always that a HLDA is issued, but this kills completelly the performance. It gets always invalidated each 15us approximatelly so the performance gain is extremelly reduced.

To gnerate this signal, the TX486 manual includes a little schematic showing how to connect it: an inverter gets connected to the ISA bus /MEMW, the inverter goes to an input of a NAND gate, the second input is connected to the CPU's HLDA and the output is used to feed the /FLUSH pin.

I did this mod, and the performance was exactly the same... After investigating with the oscilloscope it seems that my motherboard (a very, very old Tulip Vision Line WS 386SX) uses a DMA channel to do the memory refreshes, does not do hidden refresh and thus the /MEMW signal is active all the time. Thanks to a doc from Ernie van der Meer I found that in his schematic he showed two pins as possible targets: /MEMW and /SMEMW, and after checking the bus on my board I verified that using /SMEMW it gets only activated when a real DMA is transferring data.

So finally using a single 74LS00, using one gate as inverter and the second one to merge the signals, the /FLUSH mod worked properly.

### The /A20M mod

Ok, so this is not explicitly described on the manual and is based on my experience with the CPU.

When I was playing with the cache settings I found that enabling NC0 degrades also a lot the performance. This bit is set by default on the example code from Texas Instruments on the CPU manual, and did not understand why.

After doing the /FLUSH mod I started testing all the settings and found that when NC0 was not enabled the first program that I loaded failed, and the second time worked... It was very strange...

Then, after reviewing the manual I found that what NC0 is doing is protecting the first 64KB of *each 1MB block*, and this, is a workaround to make the CPU work without the A20 signal. When a program is loaded in upper ram it tends to be loaded at the beginning of the extended memory, when DOS is executed it is usually being executed from the first KB of the machine, and then, when A20 gets enabled the CPU does not see this change and the cache is not invalidated crashing the program.

I verified that this is true by disabling HIMEM.SYS, without it everything worked properly without /A20M.

So, the mod is "simple", get a signal that indicates that A20 gets enabled.

My board has a VLSI 82343 system controller, and checking the datasheet I found that there is a signall called /BLKA20, in theory is used to control if A20 is blocked or not, but that's done by merging the A20 control signal with an internal bit. At the end, this signal is really the final status of enablement of A20, so I ran a wire from it to the /A20M signal and... tadaaa! everything started working properly!

Each controller has a different way to handle the A20 enablement, so you may need to check how it is controlled, maybe it comes from the keyboard controller itself, maybe it is from another pin on your chipset, so your experience here will change based on the chipset.

In the worst case, you can enable NC0 but the performance hit is noticeable, in my case the 3DBench went from 14FPS to 10, so is veeery noticeable.

### Final tweaks

Another thing that I wanted to understand was the ARR1/4 registers and the CCR1 WPx bits. In the Texas Instruments example code it configures A0000h and C0000h as non-cacheable zones. The first one is the video memory, and the second one is the video BIOS and other BIOS expansions.

The first one is completelly clear, if you cache the video memory it will trash everything. But... why not cache the video BIOS and expansion BIOSes?

Well, after some testing I found that is because of shadowing. If you configure the machine to use BIOS shadowing, the BIOS gets copied into RAM for accelerating its access, the first time you boot the machine, as it will not have the cache enabled there is no problem (unless you are modding your bios, beware!), but if you reboot your machine *after* enabling the cache some strange things may happen, like your video card not working properly (in my case some times the video card gets in MGA mode and cannot be reverted back to SVGA mode).

After understanding it, I decided that the "problems" were worth it. In my case I have modded my BIOS and included XTIDE on it, the original BIOS had a Netware boot ROM merged, and the BIOS has the option to do network boot, so I replaced it with XTIDE and now whenever the machine tries to do the net boot it runs XTIDE and I can then use a 32GB SD card with an IDE adapter using the integrated IDE controller. The thing is that enabling the cache on this area speeds up *drastically* the access to disk, DOS command line feels snappy and smooth, wihtout it it's pretty slow (my board does not have DMA, only PIO modes, so I assume that it affects a lot more the access to the BIOS than in other mode modern boards).

So this final tweak is achieved with the TI_CACHE tool, using the /C flag (enable Cache for shadow BIOS), if in your case does not provide any benefit or don't want to have to force a power off/on whenever you reboot your machine, then you can leave it out of your settings.

### Conclusion

If you are reading this and reached this part, I assume you are also trying to upgrade an old SX motherboard with this CPU. I hope all this info has been useful and you get your machine working ;)

It has been a couple of fun days getting this to work properly, "playing" with these old machines nowadays with all the info on Internet and proper lab stuff is really nice.

Have fun!
