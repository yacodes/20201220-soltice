VSTPlugin.search

(
s.options.numBuffers = 2**24;
s.options.memSize = 2**20;
s.options.maxNodes = 2**20;
s.options.numOutputBusChannels = 24;
s.options.numInputBusChannels = 0;

s.waitForBoot {
  ~dirt = SuperDirt(2, s);

  // Samples 
  ~dirt.loadSoundFiles;
  // ~dirt.loadSoundFiles(File.getcwd +/+ "samples/samples/*");
  
  // Synthdefs
  loadRelative("./synthdefs/808.scd");

  // Virtual MIDI
  // MIDIClient.init(0, 0);
  // ~midiOut = MIDIOut.newByName("Virtual Raw MIDI 0-0", "VirMIDI 0-0");
  // ~dirt.soundLibrary.addMIDI(\midi, ~midiOut);
  // ~midiOut.latency = 0.02;

  ~dirt.start(20626, 24.collect{0});
};
)

{SinOsc.ar}.play

SynthDef(\shepard, #{ |freq=440, dur=20, direction=1, amp=0.2|
	var partialCount = 4;
	var octRange = 2 ** (partialCount / 2);
	var cycle = 1 / (partialCount * dur);
	var width = if(direction >= 0, 1, 0);
	var sig = partialCount.collect { |n|
		var offset = n / partialCount;
		var phase = (3 * pi / 2) + (2 * pi * offset);
		var vol = SinOsc.kr(cycle, phase).range(0, 1);
		var ratio = VarSaw.kr(cycle, offset, width).exprange(1/octRange, octRange);
		SinOsc.ar(freq * ratio) * vol;
	}.sum;
	sig = sig!2 * (amp / partialCount) * Line.kr(0, 1, 5); // fade in
	sig = JPverb.ar(sig); // reverb
	Out.ar(0, sig);
}).add;

Synth(\shepard)
s.freeAll

SynthDef(\drone, {
		| out,freq, dur, amp, pan, width |
		var env = EnvGen.kr(Env.new([0, 1, 1, 0], [1.0, dur, 3.0]), doneAction:Done.freeSelf);
		var sig = Array.fill(20, {
			var multiplier = [
				0.99, 1, 1.01,
				1.99, 2, 2.01,
				3.99, 4, 4.01].choose;
			var ampmult = multiplier.reciprocal;
			RLPF.ar(
				in: LFSaw.ar(
					LFNoise1.kr(0.5.rrand(1.0)).range(freq*(1-width), freq*(1+width))*multiplier,
					freq*2.0.rrand(5.0)),
				rq: LFNoise1.kr(0.5).range(0.1,0.6),
				mul:LFNoise0.kr(2.0).range(16.reciprocal, ampmult));
		});
		var finalsig = Splay.ar(env*sig);
		var finalsig_panned = Balance2.ar(
			finalsig[0],
			finalsig[1],
			pan*SinOsc.kr(LFNoise1.kr(1).range(0.05,0.2)));
		Out.ar(out, amp*finalsig_panned);
	},
	metadata: (
		credit: "Stefaan Himpe",
		category: \pad,
		tags: [\pitched]
	)).add;


Synth(\drone)
s.freeAll

SynthDef(\FMRhodes1, {
    arg
    // standard meanings
    out = 0, freq = 440, pan = 0, amp = 0.1, att = 0.001, rel = 1, lfoSpeed = 4.8, inputLevel = 0.2,
    // all of these range from 0 to 1
    modIndex = 0.2, mix = 0.2, lfoDepth = 0.1;

    var env1, env2, env3, env4;
    var osc1, osc2, osc3, osc4, snd;

    env1 = Env.perc(att, rel * 1.25, inputLevel, curve: \lin).kr;
    env2 = Env.perc(att, rel, inputLevel, curve: \lin).kr;
    env3 = Env.perc(att, rel * 1.5, inputLevel, curve: \lin).kr;
    env4 = Env.perc(att, rel * 1.5, inputLevel, curve: \lin).kr;

    osc4 = SinOsc.ar(freq) * 6.7341546494171 * modIndex * env4;
    osc3 = SinOsc.ar(freq * 2, osc4) * env3;
    osc2 = SinOsc.ar(freq * 30) * 0.683729941 * env2;
    osc1 = SinOsc.ar(freq * 2, osc2) * env1;
    snd = Mix((osc3 * (1 - mix)) + (osc1 * mix));
  	snd = snd * (SinOsc.ar(lfoSpeed).range((1 - lfoDepth), 1));

    snd = snd * Env.perc(0.01, 1.0).ar(doneAction: 2);
    snd = Pan2.ar(snd, pan, amp);
	snd = JPverb.ar(snd); // reverb

    Out.ar(out, snd);
},
metadata: (
	credit: "Nathan Ho",
	category: \keyboards,
	tags: [\pitched, \piano, \fm]
)
).add;

Env(0, 1, 0.1)

Synth(\FMRhodes1, [\amp, 1, \freq, 220])
s.freeAll

SynthDef("hihat", {arg out = 0, amp = 0.5, att = 0.01, rel = 0.2, ffreq = 6000, pan = 0;
	var env, snd;
	env = Env.perc(att, rel, amp).kr(doneAction: 2);
	snd = WhiteNoise.ar;
	snd = HPF.ar(in: snd, freq: ffreq, mul: env);
	Out.ar(out, Pan2.ar(snd, pan));
}).add;
Synth(\hihat)

SynthDef(\lead, {
		| out = 0, freq = 440, dur = 0.2, amp = 0.2, pan = 0, wobblelow=0.3, wobblehigh=1.0 |
		var atk = 0.5;
		var env = EnvGen.kr(Env([0, 1, 1, 0], [atk, dur-atk, 10]), doneAction:Done.freeSelf);
		var freqenv = EnvGen.kr(Env([0.7, 1, 1], [0.3, dur]), doneAction:Done.none);
		var sharpness = freq.cpsmidi.linlin(0,127,1,15);
		var wobble = SinOsc.kr(6).range(wobblelow, wobblehigh);
		var sig = RLPF.ar(
			in: LFSaw.ar(freqenv*freq*LFNoise1.kr(1.0).range(0.995,1.005)),
			freq:freq*sharpness,
			rq:LFNoise1.kr(3).range(0.2,0.5),
			mul:wobble);
		var panned_sig;
		var n = 10;
		n.do({ sig = AllpassN.ar(sig, 0.050, [Rand(0, 0.05), Rand(0, 0.05)], 1) });
		panned_sig = Pan2.ar(sig/n, pan);
		Out.ar(out, amp*env*panned_sig);
	},
	metadata: (
		credit: "Stefaan Himpe",
		category: \pad,
		tags: [\pitched]
	)).add;

Synth(\lead, [\dur, 0.5, \freq, 220])
Synth(\lead, [\dur, 0.5, \freq, 440])

(
SynthDef("plucking", {arg amp = 0.1, freq = 440, decay = 5, coef = 0.1, verbMix = 0.9, verbSize = 0.9, verbDamp = 0.0001, vibratoRate = 7, vibratoMul = 10, pan = 0;
	var env, snd, vibrato;
	env = Env.linen(0, decay, 0).kr(doneAction: 2);
  vibrato = SinOsc.kr(freq: freq / 2/* vibratoRate */, mul: freq/vibratoMul);
	snd = Pluck.ar(
		in: GrayNoise.ar(amp),
		trig: Impulse.kr(0),
		maxdelaytime: 0.1,
		delaytime: freq.reciprocal,
		decaytime: decay,
		coef: coef);
	snd = FreeVerb.ar(in: snd, mix: verbMix, room: verbSize, damp: verbDamp);
	snd = Pan2.ar(snd, pan);
	Out.ar(0, Splay.ar(snd, spread: 0.75, level: SinOsc.kr(freq: vibrato), center: 0));
}).add;
)
Synth("plucking", [\freq, 2000, \verbMix, 0])

SynthDef(\harpsichord_pluck, {
	|amp=0.1, freq=440, pan=0, atk=0, rel=0, trig= 1, maxdelaytime= 0.2, decaytime= 7, coef= 0.1|
	var env, sig, delay;
	env = EnvGen.kr(Env.linen(atk, decaytime, rel), doneAction: Done.freeSelf);
	sig = PinkNoise.ar(amp); //Can use white noise here, but Pink is more realistic
	delay = freq.reciprocal;
	sig = Pluck.ar(sig, trig, maxdelaytime , delay , decaytime , coef ) //fundamental
	+ Pluck.ar(sig, trig, maxdelaytime , delay/2 , decaytime , coef ); //octave higher
	Out.ar(0, Pan2.ar(sig , pan));
//Harpsichord based on Pluck Ugen
//By Zé Craum

}).add;

Synth(\harpsichord_pluck)
SynthDef("sawSynth", { arg freq = 440, amp = 0.1, att = 0.1, rel = 2, lofreq = 1000, hifreq = 3000;
    var env, snd;
    env = Env.perc(
		attackTime: att,
		releaseTime: rel,
		level: amp
	).kr(doneAction: 2);
    snd = Saw.ar(freq: freq * [0.99, 1, 1.001, 1.008], mul: env);
	snd = LPF.ar(
		in: snd,
		freq: LFNoise2.kr(1).range(lofreq, hifreq)
	);
    snd = Splay.ar(snd);
    Out.ar(0, snd);
// Basic saw synth for chords and bass
//By Bruno Ruviaro
//http://sccode.org/1-54H
}).add;
Synth(\sawSynth)

(
	SynthDef(\acid309, {|out, sustain=1, pan, accelerate, freq |
	 	var env1, env2, son, pitch, amp, gate;
	    gate=1;
	    amp = 0.5;
		pitch = freq.cpsmidi;
		pitch = Lag.kr(pitch, 0.12 * (1-Trig.kr(gate, 0.001)) * gate);
		env1 = EnvGen.ar(Env.new([0, 1.0, 0, 0], [0.001, 2.0, 0.04], [0, -4, -4], 2), gate, amp, doneAction:2);
		env2 = EnvGen.ar(Env.adsr(0.001, 0.8, 0, 0.8, 70, -4), gate);
		son = LFPulse.ar(pitch.midicps, 0.0, 0.51, 2, -1);

		son = RLPF.ar(son, (pitch + env2).midicps, 0.3);

	  // Out.ar(out, son)
	    OffsetOut.ar(out, DirtPan.ar(son, ~dirt.numChannels, pan, env1));
	}).add;

)
Synth(\acid309, [\freq, 220])
(

SynthDef(\bass8, {
	arg out = 0, amp = 0.1, gate = 1, pan = 0, freq = 200;
	var sig;
	var osc = Array.newClear(6);
	var env = Array.newClear(6);

	env[0] = EnvGen.kr(Env([0,1,0.051,0],[0.001,0.01,0.8], [4,-8]), 1);
	env[1] = EnvGen.kr(Env([0,1,0.051,0],[0.005,0.5,1.5], [0,-8], releaseNode:2), 1);
	env[2] = EnvGen.kr(Env([0,1,1,0],[0.01,0.01,0.2], [0,0,-4], releaseNode:2), gate);
	env[3] = EnvGen.kr(Env([0,1,0],[0.002,2.8], [0,-4]), 1);
	env[4] = EnvGen.kr(Env([0,1,1,0],[0.001,0.1,0.8], [4,0,-4], releaseNode:2), gate);
	env[5] = EnvGen.kr(Env([0,1,0],[0.001,3.0], [0,-4]), 1);

	freq = (freq / 4) * ((0..1)/1 - 0.5 * 0.0007 + 1);

	osc[0] = SinOsc.ar(freq * 11 + 0) * env[0];
	osc[1] = SinOsc.ar(freq * 6 * ( osc[0] * 2.5 + 1 )) * env[1];
	osc[2] = SinOsc.ar(freq * 2 * 1 + 0) * env[2];
	osc[3] = SinOsc.ar(freq * 1 * ( osc[2] * 2.5 + 1 ) + 0) * env[3];
	osc[4] = SinOsc.ar(freq * 1 * ( osc[1] * 2.5 + 1 ) * (osc[3] * 2.5 + 1)) * env[4];
	osc[5] = SinOsc.ar(freq * 2) * env[5];

	sig = osc * DC.ar([0.0, 0.0, 0.0,  0.0, 0.5, 0.5]);
	sig = sig * 0.5;
	sig = sig.flop.sum;
	sig = sig * EnvGen.ar(\adsr.kr( Env.adsr(0.001,0,1,0.01, 1,-1) ), gate, doneAction:2);
	sig = sig * AmpComp.kr(freq);
	sig = sig.sum;
	Out.ar(out, Pan2.ar(sig, pan, amp));

}).add;
)
Synth(\bass8)
s.freeAll

SynthDef(\cs80lead, {

		arg freq=880, amp=0.5, attack=0.75, decay=0.5, sustain=0.8, release=1.0, fatt=0.75, fdecay=0.5, fsus=0.8, frel=1.0,
			cutoff=200, pan=0, dtune=0.002, vibrate=4, vibdepth=0.015, gate=1.0, ratio=1,out=0,cbus=1;
		var env,fenv,vib,ffreq,sig;
		cutoff=In.kr(cbus);
		env=EnvGen.kr(Env.adsr(attack,decay,sustain,release),gate,levelScale:1,doneAction:2);
		fenv=EnvGen.kr(Env.adsr(fatt,fdecay,fsus,frel,curve:2),gate,levelScale:1,doneAction:2);
		vib=SinOsc.kr(vibrate).range(-1*vibdepth,vibdepth)+1;
		freq=Line.kr(freq,freq*ratio,5);
		freq=freq*vib;
		sig=Mix.ar(Saw.ar([freq,freq*(1+dtune)]));
		// keep this below nyquist!!
		ffreq=max(fenv*freq*12,cutoff)+100;
		sig=LPF.ar(sig,ffreq);


	    OffsetOut.ar(out, DirtPan.ar(sig, ~dirt.numChannels, pan, env));


	}).add;	

Synth(\cs80lead)

s.freeAll
(
//https://sccode.org/1-4YY
SynthDef(\pbass, {
  arg out = 0, pan = 0, freq = 200;
  var subfreq = freq / 2;

  // Envelopes
  var subenv = EnvGen.kr(Env.perc(0, 1), doneAction:2);
  var env = EnvGen.kr(Env.perc(0, 0.5));

  // Component synthesis
  var pluck = Pluck.ar(PinkNoise.ar, 1, 0.2, subfreq.reciprocal) * subenv * 2;
  var tri = VarSaw.ar(freq) * env;
  var sin = SinOsc.ar(freq) * env;
  var sub = (SinOsc.ar([subfreq, subfreq - 2, subfreq + 2]).sum * subenv).tanh;
  var click = RLPF.ar(Impulse.ar(0), [2000, 8000], 1).sum * 1000;

  // Initial signal
  var sig = pluck + tri + sub + click;

  // Resonant LPFs
  sig = RLPF.ar(sig, XLine.ar(freq * 100, freq * 10, 0.15));
  sig = sig + (MoogFF.ar(sig, freq * 20, 2.5) * 0.1);

  // EQ resulting signal
  sig = BPeakEQ.ar(sig, 400, 0.5, -9);
  sig = BPeakEQ.ar(sig, 2000, 0.5, 6);
  sig = BHiShelf.ar(sig, 8000, 1, 3);
  sig = BPeakEQ.ar(sig, 200, 1, 3);

  // Apply another envelope to dampen a bit more
  sig = sig * XLine.kr(1, 0.6, 0.1);

  // Tanh distortion / limiting
  sig = (sig * 1).tanh;

  // Another round of signal coloring, using another RLPF
  // and sine components
  sig = sig + RLPF.ar(sig, XLine.ar(freq * 100, freq * 10, 0.15)) + sin + sub;

  // Another round of tanh distortion / limiting
  sig = (sig / 2.3).tanh;

  // Another resonant LPF
  sig = MoogFF.ar(sig, XLine.ar(freq*150, freq*30, 0.1), 0.1);

  OffsetOut.ar(out, DirtPan.ar(sig, ~dirt.numChannels, pan, env));

}).add;
)

Synth(\pbass, [\freq, 100])

(

SynthDef(\rhodes, {|out, sustain=1, pan, accelerate, freq |
  var sig, in, n = 6, max = 0.04, min = 0.01, delay, pitch, detune, hammer, amp, env;
  amp = 0.9;
	freq = freq.cpsmidi;
	hammer = Decay2.ar(Impulse.ar(0.001), 0.008, 0.04, LFNoise2.ar([2000,4000].asSpec.map(amp), 0.25));
	sig = Mix.ar(Array.fill(3, { arg i;
			detune = #[-0.04, 0, 0.03].at(i);
			delay = (1/(freq + detune).midicps);
			CombL.ar(hammer, delay, delay, 50 * amp)
		}) );

	sig = HPF.ar(sig,50);
    env = EnvGen.ar(Env.perc(0.0001,sustain, amp * 4, -1), doneAction:2);
    OffsetOut.ar(out, DirtPan.ar(sig, ~dirt.numChannels, pan, env));
}).add;

)

Synth(\rhodes, [\freq, 220])
(

//no use of gate, fixed length
SynthDef(\moogbasstone,{|out= 0 freq = 440 amp = 0.1 gate=1 cutoff= 1000 gain=2.0 lagamount = 0.01 pan=0.0|

	var osc, filter, env, filterenv;

	osc = Mix(VarSaw.ar(freq.lag(lagamount)*[1.0,1.001,2.0],Rand(0.0,1.0)!3,Rand(0.5,0.75)!3,0.33));

	//alternative: richer source: see moogbasstone2 below
	//osc = Mix(Pulse.ar(freq.lag(lagamount)*[1.0,1.001,2.0],Rand(0.45,0.5)!3,0.33));

	filterenv = EnvGen.ar(Env.adsr(0.2,0.0,1.0,0.2),gate,doneAction:2);
	filter =  MoogFF.ar(osc,cutoff*(1.0+(0.5*filterenv)),gain);

	env = EnvGen.ar(Env.adsr(0.001,0.3,0.9,0.2),gate,doneAction:2);

	Out.ar(out,Pan2.ar((0.7*filter+(0.3*filter.distort))*env*amp*1.5,pan));

}).add;

)
(

SynthDef(\xenbass, {|out=0,pan=0,freq=440,tuning=19,attack=0.001,release=1,depth=1,sustain=1,begin=0,end=1,speed=1|
  var envLength = sustain*(end-begin)/speed;
  var line = Line.ar(begin, end, envLength, doneAction: Done.freeSelf);
  var env = Env.asr(attackTime: attack, releaseTime: release);
  var volume = IEnvGen.ar(env, line);
  var signal, freqenv;
  var note = freq.cpsmidi;
  var octave = ((note/tuning)-5).trunc(1);
  freq = [440 * (pow(2, octave)) * (pow(2, ((mod(note, tuning))/tuning)))];  //sets microtonal properties according to Guiot's technique
  freqenv = EnvGen.ar(Env([freq, freq * 6, freq], [attack, release], 'exp')); // filter envelope
  signal = Gendy1.ar(1, 5, 1, 1, freq, [freq + depth, freq + depth + 1 ], 0.5, 0.6, 6); // a Gendy1 oscillator
  signal = LPF.ar(signal, freqenv); // applies filter and amplitude envelope to the oscillator
  signal = LeakDC.ar(signal); //remove DC Offset
  signal = Mix.ar(signal);

  Out.ar(out, DirtPan.ar(signal * volume, ~dirt.numChannels, pan));
}).add;

);
Synth(\xenbass)

(
SynthDef(\tubes, { |out=0, pan=0, depth=0.3, freq=440, detune=0, begin=0, end=1, sustain=1|
  var line = Line.ar(begin, end, sustain*(end-begin), doneAction: Done.freeSelf);
  var f1 = freq.clip(3, 5000);
  var f2 = (freq.cpsmidi - detune).midicps.clip(3, 5000);
  var source = WhiteNoise.ar(0.5) * EnvGen.ar(Env([1,1,0],[(f1+f2)/SampleRate.ir,0.0]));
  var volume = IEnvGen.ar(Env.asr, line);
  var sig = TwoTube.ar(
    source,
    depth.linlin(0, 1, -1, 1),
    0.999,
    f1,
    f2
  );
  OffsetOut.ar(out, DirtPan.ar(sig, ~dirt.numChannels, pan, volume));
}).add;
);

Synth(\tubes)

(
SynthDef(\xenharp, { arg out, pan, freq = 440, tuning = 19, attack = 0.001, release = 1, depth = 1;
	var signal, env, filterenv;
	var note = freq.cpsmidi;
	var octave = ((note/tuning)-5).trunc(1);
	freq = [440 * (pow(2, octave)) * (pow(2, ((mod(note, tuning))/tuning)))];  //sets microtonal properties according to Guiot's technique
	filterenv = EnvGen.ar(Env([freq, 10000, freq ], [attack, release], [-4, -1])); //filter envelope
	env = EnvGen.ar(Env([0.0001, 1, 0.0001], [attack, release], [-10, -1]), doneAction: 2); //amplitude envelope
	signal = Gendy1.ar(3, 5, 1, 1, [freq, freq + 1], [freq + depth + 0.5, freq + depth], 0.0005, 0.0005, 25); //oscillator
	signal = RLPF.ar(signal, filterenv, 0.95); // resonant filter with filter envelope
	signal = LeakDC.ar(signal * env); // applies amplitude envelope and a DC block
	signal = Mix.ar(signal); //necessary for panning
	OffsetOut.ar(out, DirtPan.ar(signal, ~dirt.numChannels, pan, env)); //configures the synth for Tidalcycles
}).add;
);
Synth(\xenharp)

// Borrowed from efairbanks
// https://github.com/efairbanks/tidal-performance-2019/blob/master/synthdefs.scd
SynthDef(\donk, {
    |out, sustain = 1, freq = 440, speed = 1, begin=0, end=1, pan, accelerate, offset|
    var line = Line.ar(begin, end, sustain, doneAction:2);
    var env = Env([0, 1, 0], [0.01, 1], curve:-3);
    var envGen = IEnvGen.ar(env, line*env.times.sum*abs(speed));
    var modulator = (SinOsc.ar(freq*[1.0001,0.9999]*abs(speed))*2).tanh;
    var carrier = (SinOsc.ar((freq/4)+(modulator*1000*envGen))*0.8).tanh;
    var sound = DirtPan.ar(carrier, ~dirt.numChannels, pan, envGen);
    Out.ar(out, sound);
  }).add;
 
Synth(\donk, [\freq, 220])

 SynthDef(\wub, {
    |out, sustain = 1, freq = 440, speed = 1, begin=0, end=1, pan, accelerate, offset|
    var line = Line.ar(begin, end, sustain, doneAction:2);
    var env = Env([0, 1, 0],[1,5], curve:2);
    var envGen = IEnvGen.ar(env, line*env.times.sum*abs(speed));
    // --- //
    var speedFreq = freq*abs(speed)/4;
    var mod = Latch.ar((SinOsc.ar(speedFreq*[7,11,13,5])*5).tanh*2000*envGen, Saw.ar(21000*envGen));
    var car =  Latch.ar(((SinOsc.ar(speedFreq+mod)*10)+(SinOsc.ar(speedFreq)!2)).tanh, Saw.ar(21000*envGen));
    var sound = LPF.ar(car, DC.ar(20000)*envGen+DC.ar(10))*(-11.dbamp);
    Out.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, envGen));
  }).add;

Synth(\wub, [\freq, 220])

SynthDef(\sawpluck, {
    |out, sustain = 1, freq = 440, speed = 1, begin=0, end=1, pan, accelerate, offset|
    var line = Line.ar(begin, end, sustain, doneAction:2);
    var env = Env([0, 1, 0.333, 0],[5, 70, 1000]);
    var envGen = IEnvGen.ar(env, line*env.times.sum*abs(speed));
    var sound = Saw.ar(freq*abs(speed));
    Out.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, envGen));
  }).add;

Synth(\sawpluck)

  SynthDef(\vibsawpluck, {
    |out, sustain = 1, freq = 440, speed = 1, begin=0, end=1, pan, accelerate, offset|
    var line = Line.ar(begin, end, sustain, doneAction:2);
    var env = Env([0, 1, 0.333, 0],[5, 70, 1000]);
    var envGen = IEnvGen.ar(env, line*env.times.sum*abs(speed));
    var sound = Saw.ar(freq*abs(speed)+(SinOsc.ar(10)*(freq*0.06)*line*line));
    sound = RLPF.ar(sound, Clip.ar(envGen*freq*48, 0, 20000), 0.5);
    Out.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, envGen));
  }).add;
Synth(\vibsawpluck)

  SynthDef(\plucklead, {
    |out, sustain = 1, freq = 440, speed = 1, begin=0, end=1, pan, accelerate, offset|
    var line = Line.ar(begin, end, sustain, doneAction:2);
    var env = Env([0, 1, 0.333, 0],[5, 70, 1000]);
    var envGen = IEnvGen.ar(env, line*env.times.sum*abs(speed));
    var speedFreq = freq*abs(speed);
    var pulseLfo = SinOsc.ar(Rand(-1,1));
    var sound = RLPF.ar(Pulse.ar([speedFreq*Rand(0.99,1.01)*2,speedFreq*Rand(0.99,1.01)*2],pulseLfo)*0.5+Saw.ar(speedFreq), (20000*(envGen**2.8))+DC.ar(10), 0.5);
    Out.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, envGen));
  }).add;

Synth(\plucklead)

  SynthDef(\wob, {
    |out, sustain = 1, freq = 440, speed = 1, begin=0, end=1, pan, accelerate, offset|
    var line = Line.ar(begin, end, sustain, doneAction:2);
    var env = Env([0, 1, 0],[1, 1]);
    var envGen = IEnvGen.ar(env, line*env.times.sum*abs(speed));
    // --- //
    var speedFreq = freq*abs(speed)/4;
    var mod = Latch.ar((SinOsc.ar(speedFreq*[7,11,13,5])*5).tanh*2000*envGen, Saw.ar(21000*envGen));
    var car =  Latch.ar(((SinOsc.ar(speedFreq+mod)*10)+(SinOsc.ar(speedFreq)!2)).tanh, Saw.ar(21000*envGen));
    var sound = car*(-10.dbamp);
    Out.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, envGen));
  }).add;
Synth(\wob)

  SynthDef(\noisebuild, {
    |out, sustain = 1, speed = 1, begin=0, end=1, pan, accelerate, offset|
    var line = Line.ar(begin, end, sustain, doneAction:2);
    var env = Env([0, 1, 0],[127, 1],curve:4);
    var envGen = IEnvGen.ar(env, line*env.times.sum/*abs(speed)*/);
    // --- //
    var sound = HPF.ar(BPF.ar(WhiteNoise.ar()*envGen, 10+(20000*envGen), 0.8), 1000);
    Out.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, envGen));
  }).add;
Synth(\noisebuild)

  SynthDef(\fmp, {
      |out,sustain = 1,freq = 440,speed = 1,begin=0,end=1,pan,accelerate,offset,cStartFreq=440,cEndFreq=440,cEnvFMod=0,mStartFreq=440,mEndFreq=440,mEnvFMod=0,fMod=0,pMod=0,cFFeedback=0,cPFeedback=0,mFFeedback=0,mPFeedback=0,feedbackDelay=0.01,attackCurve=1,decayCurve=1,atk=1,dcy=1|
      var line = Line.ar(begin, end, sustain, doneAction:2);
      var env = Env([0, 1, 0],[atk,dcy],[attackCurve,decayCurve]);
      var envGen = IEnvGen.ar(env, line*env.times.sum*abs(speed));
      var feedback = LocalIn.ar(1);
      var mFreq = ((1-line)*mStartFreq)+(line*mEndFreq)+(envGen*mEnvFMod)+(mFFeedback*feedback);
      var mPhase = mPFeedback*feedback;
      var modulator = SinOsc.ar(mFreq,mPhase)*envGen;
      var cFreq = ((1-line)*cStartFreq)+(line*cEndFreq)+(envGen*cEnvFMod)+(modulator*fMod)+(cFFeedback*feedback);
      var cPhase = (modulator*pMod)+(cPFeedback*feedback);
      var carrier = SinOsc.ar(cFreq,cPhase);
      var sound = carrier*envGen;
      LocalOut.ar(DelayL.ar(sound,10,feedbackDelay));
      Out.ar(out, DirtPan.ar(sound,~dirt.numChannels,pan,1));
  }).add;
 
Synth(\fmp)

  SynthDef(\ab2, {
	arg out, freq = 440, sustain = 5, speed = 1, begin =0, end=1, pan, accelerate, offset;
	var line = Line.ar(begin, end, sustain, doneAction:2);
	var env = Env([0, 1, 0], [0.01, 1], curve:-3);
	var envGen = IEnvGen.ar(env, line*env.times.sum*abs(speed));
	var snd;
	var sound;
	snd = Saw.ar([freq, freq*1.022]);
	8.do { |k|
		var trig, ffreq;
		snd = AllpassN.ar(snd, 1, 0.1 / (12 - k), 2);
		trig = Impulse.ar(2 ** (8 - k) / 32, 1 / 2);
		ffreq = 80 ** TRand.ar(1, 2, trig).lag((2 ** (8 - k)).reciprocal);
		snd = BRF.ar(snd, ffreq, 2);
	};
	sound = DirtPan.ar(snd, ~dirt.numChannels, pan, envGen);
	Out.ar(out, sound);
}).add;

Synth(\ab2)

SynthDef(\flutter, {
	|out, sustain = 1, freq = 440, speed = 1, begin=0, end=1, pan, accelerate, offset|
	var line = Line.ar(begin, end, sustain, doneAction:2);
	var env = Env([0,1,0],[0.2,0.8]);
	var envGen = IEnvGen.ar(env, line*env.times.sum*abs(speed));
	var lfo = SinOsc.ar(Rand(-0.1,0.1),Rand(0,3.145))*(freq*abs(speed))/80;
	var sound = Saw.ar((freq*abs(speed))+lfo+(Rand(-1,1)*(freq*abs(speed))/DC.ar(100)));
	sound = LPF.ar(sound, (freq*abs(speed))*1.5);
	//sound = RLPF.ar(sound, Clip.ar(envGen*freq*48, 0, 20000), 0.5);
	Out.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, envGen));
}).add;
Synth(\flutter)

SynthDef(\futuresaw, {
	|out, sustain = 1, freq = 440, speed = 1, begin=0, end=1, pan, accelerate, offset|
	var line = Line.ar(begin, end, sustain, doneAction:2);
	var envCurve = -1.5;
	var env = Env([0,1,0],[0.5,0.5],[-1*envCurve,envCurve]);
	var envGen = IEnvGen.ar(env, line*env.times.sum*abs(speed));
	var sound = Saw.ar((freq*abs(speed))+(Rand(-1,1)*(freq*abs(speed))/DC.ar(100)));
	sound = RLPF.ar(sound, Clip.ar(envGen*freq*48, 0, 20000), 0.5);
	Out.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, envGen));
}).add;
Synth(\futuresaw)

SynthDef(\futuresub, {
	|out, sustain = 1, freq = 440, speed = 1, begin=0, end=1, pan, accelerate, offset|
	var line = Line.ar(begin, end, sustain, doneAction:2);
	var envCurve = 5;
	var env = Env([0,1,0],[0.5,0.5],[-1*envCurve,envCurve]);
	var envGen = IEnvGen.ar(env, line*env.times.sum*abs(speed));
	var sound = SinOsc.ar((freq*abs(speed))+(Rand(-1,1)*(freq*abs(speed))/DC.ar(100)));
	sound = sound*2;
	sound = sound.tanh;
	Out.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, envGen));
}).add;
Synth(\futuresub, [\freq, 110])

SynthDef(\ultrasaw, {
	|out, sustain = 1, freq = 440, speed = 1, begin=0, end=1, pan, accelerate, offset|
	var line = Line.ar(begin, end, sustain, doneAction:2);
	var env = Env([0,1,1,0],[0.001,1,0.001]);
	var envGen = EnvGen.ar(env, line*env.times.sum*abs(speed));
	var freqs = {Rand(-1,1)*(freq/60)}.dup(12);
	var sound = Saw.ar((freq+freqs));
	sound = sound + Saw.ar((freq+freqs)*2);
	sound = sound + Saw.ar((freq+freqs)*0.5);
	sound = sound + Saw.ar((freq+freqs)*4);
	sound = sound + Saw.ar((freq+freqs)*0.25);
	sound = LPF.ar(sound, freq*1.5);
	// sound = RLPF.ar(sound, Clip.ar(envGen*freq*48, 0, 20000), 0.5);
	Out.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, envGen));
}).add;
Synth(\ultrasaw, [\freq, 110])

SynthDef(\acid, {
	|out, sustain = 1, freq = 440, speed = 1, begin=0, end=1, pan, accelerate, offset, clamp=1, res=0.2, mix=0.1|
	var line = Line.ar(begin, end, sustain, doneAction:2);
	var env = Env([0, 1, 0], [0.01, 1], curve:-3);
	var envGen = IEnvGen.ar(env, line*env.times.sum*abs(speed));
	var carrier = RLPF.ar((Saw.ar(freq)*(1-mix))+(Pulse.ar(freq)*mix), envGen*clamp*18000,res);
	var sound = DirtPan.ar(carrier, ~dirt.numChannels, pan, envGen);
	Out.ar(out, sound);
}).add;
Synth(\acid, [\freq, 110])


SynthDef("acidOto3092", {
	arg
	// Standard Arguments
	out = 0, freq = 440, amp = 0.1, pan = 0, att = 0.001, rel = 0.5,
	// Other Controls
	// width is 0 to 1
	// filterRange is in octaves
	lagTime = 0.12, filterRange = 6, width = 0.51, rq = 0.3;

	var ampEnv, filterEnv, snd, pitch;

	pitch = freq.cpsmidi; // Lag only useful if synth is played with Pmono

	ampEnv = Env.perc(
		attackTime: att,
		releaseTime: rel,
		level: amp
	).kr(doneAction: 2);

	filterEnv = Env.perc(
		attackTime: att,
		releaseTime: rel,
		level: filterRange * 12, // octaves to semitones
	).kr;

	snd = LFPulse.ar(freq: pitch.midicps, width: width).range(-1, 1);

	// filter sweeps from current pitch all the way up to <filterRange> octaves above and back down.
	snd = RLPF.ar(snd, (pitch + filterEnv).midicps, rq).distort;

	snd = snd * ampEnv;

	Out.ar(out, Pan2.ar(snd, pan));
},
metadata: (
	credit: "based on 08091500Acid309 by otophilia",
	category: \bass,
	tags: [\pitched, \acid, \phat, \subtractive]
	)
).add;
Synth(\acidOto3092, [\freq, 110])