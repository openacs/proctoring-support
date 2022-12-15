// A class to implement lightweight student "proctoring" on
// browser-based applications.
//
// It works by grabbing audio or video input devices in this way:
//  1. audio - when an audio device is grabbed, any noise detected for
//             longer than a certain time time threshold will be made
//             into an opus-encoded webm audio file and passed to
//             configured callbacks
//  2. video - snapshots of configured video devices are captured from
//             the browser at random intervals in one or more of
//             configured image formats specified and passed to
//             configured callbacks
//
// Video capture supports still frame images (as jpeg or png) and also
// animated gifs created by concatenating all frames collected so
// far. Every image is automatically watermarked with current
// timestamp and can be configured to be converted to grayscale
// (useful to generate smaller files at the expense of colors).
//
// Dependencies: gif.js (http://jnordberg.github.io/gif.js/) (only to
// generate animated gifs)
//
// Author: Antonio Pisano (antonio@elettrotecnica.it)
//
// Usage: to start a proctored session, create a new Proctoring
// instance by by passing a configuration object to it.
//
// ## General Configuration Object Attributes ##
//
// - minMsInterval: applies to video stream grabbing. Min
//                  time interval to pass between two consecutive
//                  snapshots in milliseconds
// - maxMsInterval: applies to video stream grabbing. Max
//                  time interval to pass between twp consecutive
//                  snapshots in milliseconds
// - minAudioDuration: when audio is recorded, any noisy interval
//                    longer than this number of seconds will be
//                    transformed in an audio file
// - maxAudioDuration: when audio is recorded, recordings longer than
//                     this number of seconds will be stopped
//                     automatically so that no recordings will be
//                     longer than this value
// - onMissingStreamHandler: this javascript handler will be triggered
//                           when one on more of the required streams
//                           becomes unavailable during the proctoring
//                           session (e.g. user disconnects the
//                           camera, or other error
//                           condition). Receives in input
//                           'streamName', name of the failing stream
//                           and 'errMsg', returned error message.
// - onMicrophoneTooLowHandler: this javascript handler will be
//                              triggered when audio signal (currently
//                              coming only from the camera due to
//                              browsers limitations) detects too
//                              little noise for the microphone to be
//                              actually working. Takes no argument.
// - onReadyHandler: this javascript handler is triggered as soon as
//                   the user has given access to all necessary input
//                   streams so that the proctored session can
//                   start. Does not receive any argument.
// - mediaConf: a JSON object that can have up to two attributes,
//              'camera', or 'desktop', to define the proctoring
//              behavior and multimedia input configuration for the
//              two kinds of devices. Each attribute's value is also a
//              JSON object, see ("Media Configuration Attributes" section).
//
// ## Media Configuration Attributes ##
//
// Each attribute 'camera' or 'desktop' from mediaConf supports the
// following attributes:
// - required: this boolean flag decides if the stream is required and
//             if proctoring should fail whenever this is not
//             available. Defaults to false
// - grayscale: boolean flag deciding if the captured images from this
//              stream should be converted to grayscale. Defaults to
//              false.
// - width / height: forced width and height. Tells the proctoring
//                   object that images from this stream should be
//                   forcefully rescaled to this size regardless of
//                   the size they were captured. Needed to create
//                   lower resolution images from devices
//                   (e.g. webcams) that cannot produce images this
//                   small, as some Apple cameras.
// - imageHandlers: a JSON object defining the handlers to be
//                  triggered whenever a new image from this stream is
//                  available. It supports 3 possible attributes, each
//                  named after the corresponding image type, 'png',
//                  'jpeg' and 'gif'. The presence of one of such
//                  attributes will enable the generation of an image
//                  in that type whenever a new snapshot is
//                  taken. Each attribute supports itself two possible
//                  attributes defining the handler type, 'blob', or
//                  'base64'. The value of each of those is a
//                  javascript handler that expects to receive the
//                  blob or base64 value respectively of the generated
//                  image.
// - audioHandlers: a JSON object currently supporting just one 'auto'
//                  attribute. The value of this attribute is a
//                  javascript handler called whenever a new audio
//                  recording is available, receiving the blob file
//                  containing the audio recording. When this
//                  attribute is missing, audio will not be recorded.
// - stream: one can specify a ready to use MediaStream for camera or
//           desktop. In this case, the acquiring of the device will
//           be completely skipped and the stream will be assumed to
//           comply with any user constraint
// - constraints: a MediaTrackConstraints JSON object defining the
//                real multimedia constraints for this device. See
//                https://developer.mozilla.org/en-US/docs/Web/API/MediaTrackConstraints
//
// Example conf:
//
// const conf = {
//     minMsInterval: 5000,
//     maxMsInterval: 10000,
//     minAudioDuration: 1,
//     maxAudioDuration: 60,
//     onMissingStreamHandler : function(streamName, errMsg) {
//         alert('\'' + streamName + '\' stream is missing. Please reload the page and enable all mandatory input sources.');
//     },
//     onReadyHandler : function(streamName, errMsg) {
//         console.log("All set!");
//     },
//     mediaConf: {
//         camera: {
//             required: true,
//             grayscale: true,
//             width: 320,
//             width: 240,
//             imageHandlers: {
//                    gif: {
//                        base64: function(base64data) {
//                            // this handler will be triggered
//                            // every time a new gif for this stream is
//                            // rendered and will receive the base64
//                            // data in input
//                            const input = document.querySelector('input[name="proctoring1"]');
//                            input.value = base64data;
//                        }
//                    },
//                    png {
//                        blob: function(blob) {
//                            pushImageToServer(blob);
//                        }
//                    }
//             },
//             audioHandlers = {
//                   auto: function(blob) {
//                       // Do something with the audio blob
//                   }
//             },
//             constraints: {
//                 video: {
//                     width: { max: 640 },
//                     height: { max: 480 }
//                 }
//             }
//         },
//         desktop: {
//             required: true,
//             grayscale: false,
//             imageHandlers: {
//                    gif: {
//                        base64: function(base64data) {
//                            // this handler will be triggered
//                            // every time a new gif for this stream is
//                            // rendered and will receive the base64
//                            // data in input
//                            const input = document.querySelector('input[name="proctoring1"]');
//                            input.value = base64data;
//                        }
//                    },
//                    png {
//                        base64: ...some handler
//                        blob:...
//                    },
//                    jpeg {
//                        ...
//                        ...
//                    }
//             },
//             constraints: {
//                 video: {
//                     width: { max: 640 },
//                     height: { max: 480 }
//                 }
//             }
//         }
//     }
// };
// const proctoring = new Proctoring(conf);
// proctoring.start();
//

Date.prototype.toTZISOString = function() {
    const tzo = -this.getTimezoneOffset();
    const dif = tzo >= 0 ? '+' : '-';
    const pad = function(num) {
        const norm = Math.floor(Math.abs(num));
        return (norm < 10 ? '0' : '') + norm;
    };
    return this.getFullYear() +
        '-' + pad(this.getMonth() + 1) +
        '-' + pad(this.getDate()) +
        'T' + pad(this.getHours()) +
        ':' + pad(this.getMinutes()) +
        ':' + pad(this.getSeconds()) +
        dif + pad(tzo / 60) +
        ':' + pad(tzo % 60);
}

// Implements a recorder automatically grabbing audio samples when
// noise is detected for longer than a specified interval
class AutoAudioRecorder {
    constructor(stream,
                ondataavailable,
                onmicrophonetoolow,
                minDuration=5,
                maxDuration=60,
                sampleInterval=50) {
        const self = this;

        this.stream = new MediaStream();

        const audioTracks = stream.getAudioTracks();
        if (audioTracks.length === 0) {
            throw 'No audio track available in supplied stream';
        }

        // Get only audio tracks from the main stream object
        for (const track of audioTracks) {
            this.stream.addTrack(track);
        };

        this.ondataavailable = ondataavailable;
        this.onmicrophonetoolow = onmicrophonetoolow;
        this.sampleInterval = sampleInterval;
        this.minDuration = minDuration;
        this.maxDuration = maxDuration;
        this.stopHandle = null;

        // Prepare to sample stream properties
        this.audioCtx = new window.AudioContext();
        this.analyser = this.audioCtx.createAnalyser();
        this.source = this.audioCtx.createMediaStreamSource(this.stream);
        this.source.connect(this.analyser);
        this.analyser.fftSize = 2048;
        this.bufferLength = this.analyser.frequencyBinCount;
        this.dataArray = new Uint8Array(this.bufferLength);

        this.numPositiveSamples = 0;
        this.noise = 0;

        // Audio frames we skip at the beginning when we check for
        // silence, as the audio stream might start with a silent
        // interval due to initialization. We skip the first ~5s
        this.NSKIPSILENTFRAMES = 5000 / this.sampleInterval;
        this.nSkipSilentFrames = this.NSKIPSILENTFRAMES;

        // Create an audio recorder
        this.recorder = new MediaRecorder(this.stream, {
            mimeType: 'audio/webm'
        });

        this.recorder.addEventListener('dataavailable', function(e) {
            if (self.currentDuration() >= self.minDuration) {
                self.ondataavailable(e.data);
            }
            self.numPositiveSamples = 0;
        });
    }

    currentDuration() {
        return (this.sampleInterval * this.numPositiveSamples) / 1000;
    }

    someNoise() {
        this.analyser.getByteTimeDomainData(this.dataArray);
        let max = 0;
        for (const data in this.dataArray) {
            const v = (data - 128.0) / 128.0;
            if (v > max) {
                max = v;
            }
        }
        const decay = 500 / this.sampleInterval;
        this.noise = (this.noise * (decay - 1) + max) / decay;

        if (this.nSkipSilentFrames === 0 &&
            this.noise < Math.pow(10, -10)) {
            if (typeof this.onmicrophonetoolow === 'function') {
                this.onmicrophonetoolow();
                this.nSkipSilentFrames = this.NSKIPSILENTFRAMES;
            }
        } else if (this.nSkipSilentFrames > 0) {
            this.nSkipSilentFrames--;
            // console.log('skipping: ' + this.nSkipSilentFrames);
        }

        return max > 0.01;
    }

    silence() {
        // console.log(this.noise);
        return this.noise <= 0.01
    }

    autoRecord() {
        if (this.someNoise()) {
            if (this.recorder.state !== 'recording') {
                this.recorder.start();
            }
            this.numPositiveSamples++;
        } else if (this.recorder.state !== 'inactive' &&
                   this.silence()) {
            this.recorder.stop();
        }
        if (this.recorder.state !== 'inactive' &&
            this.currentDuration() >= this.maxDuration) {
            this.recorder.stop();
        }
    }

    start() {
        this.stop();
        this.stopHandle = setInterval(this.autoRecord.bind(this), this.sampleInterval);
    }

    stop() {
        if (this.stopHandle !== null) {
            clearInterval(this.stopHandle);
        }
        if (this.recorder.state !== 'inactive') {
            this.recorder.stop();
        }
    }
}

class Proctoring {

    constructor(conf) {
        this.minMsInterval = conf.minMsInterval;
        this.maxMsInterval = conf.maxMsInterval;
        this.minAudioDuration = conf.minAudioDuration;
        this.maxAudioDuration = conf.maxAudioDuration;
        this.mediaConf = conf.mediaConf;

        this.streamNames = Object.keys(this.mediaConf);
        this.numStreams = this.streamNames.length;
        this.numCheckedStreams = 0;
        this.numActiveStreams = 0;

        this.onReadyHandler = conf.onReadyHandler;
        this.ready = false;
        this.onMissingStreamHandler = conf.onMissingStreamHandler;
        this.onMicrophoneTooLowHandler = conf.onMicrophoneTooLowHandler;
        this.isMissingStreams = false;
        this.streamErrors = [null, null];

        this.gifs = [null, null];
        this.imageHandlers = [null, null];
        this.audioHandlers = [null, null];
        this.pictures = [[], []];
        this.prevPictures = [null, null];
        this.streams = [null, null];
        this.videos = [null, null];

        for (let i = 0; i < this.numStreams; i++) {
            const streamName = this.streamNames[i];
            const conf = this.mediaConf[streamName];
            // streams are not required by default
            if (conf.required === undefined) {
                conf.required = false;
            }
            if (conf.imageHandlers !== undefined) {
                this.imageHandlers[i] = conf.imageHandlers;
            }
            if (conf.audioHandlers !== undefined) {
                this.audioHandlers[i] = conf.audioHandlers;
            }
            if (conf.stream instanceof MediaStream) {
                if (streamName === 'camera') {
                    this.useCameraStream(conf.stream);
                } else {
                    this.useDesktopStream(conf.stream);
                }
            }
        }

        this.acquireDevices();
    }

    useCameraStream(stream) {
        const i = this.streamNames.indexOf('camera');
        if (this.audioHandlers[i] !== null) {
            new AutoAudioRecorder(stream,
                                  this.audioHandlers[i].auto,
                                  this.onMicrophoneTooLowHandler,
                                  this.minAudioDuration,
                                  this.maxAudioDuration).start();
        }
        this.streams[i] = stream;
        if (stream.getVideoTracks().length > 0) {
            this.videos[i] = this.createVideo(stream);
        }
        this.numActiveStreams++;
        this.numCheckedStreams++;
    }

    useDesktopStream(stream) {
        const i = this.streamNames.indexOf('desktop');
        this.streams[i] = stream;
        this.videos[i] = this.createVideo(stream);
        this.numActiveStreams++;
        this.numCheckedStreams++;
    }

    acquireDevices() {
        const self = this;

        // Cam stream
        if (this.mediaConf.camera !== undefined &&
            this.mediaConf.camera.stream === undefined) {
            if (!navigator.mediaDevices.getUserMedia) {
                const err = 'getUserMedia not supported';
                self.streamErrors[self.streamNames.indexOf('camera')] = err;
                console.log('Camera cannot be recorded: ' + err);
                self.numCheckedStreams++;
            } else {
                navigator.mediaDevices.getUserMedia(this.mediaConf.camera.constraints).then(stream => {
                        this.useCameraStream(stream);
                    })
                    .catch(function (err) {
                        self.streamErrors[self.streamNames.indexOf('camera')] = err;
                        console.log('Camera cannot be recorded: ' + err);
                        if (err.name === 'AbortError') {
                            self.numCheckedStreams = self.numStreams;
                        } else {
                            self.numCheckedStreams++;
                        }
                    });
            }
        }

        // Desktop stream
        if (this.mediaConf.desktop !== undefined &&
            this.mediaConf.desktop.stream === undefined) {
            if (!navigator.mediaDevices.getDisplayMedia) {
                const err = 'getDisplayMedia not supported';
                self.streamErrors[self.streamNames.indexOf('desktop')] = err;
                console.log('Desktop cannot be recorded: ' + err);
                self.numCheckedStreams++;
            } else {
                navigator.mediaDevices.getDisplayMedia(this.mediaConf.desktop.constraints).then(stream => {
                        const requestedStream = this.mediaConf.desktop.constraints.video.displaySurface;
                        const selectedStream = stream.getVideoTracks()[0].getSettings().displaySurface;
                        // If displaySurface was specified, browser
                        // MUST support it and MUST be the right one.
                        if (requestedStream === undefined ||
                            (selectedStream !== undefined &&
                             requestedStream === selectedStream)) {
                            this.useDesktopStream(stream);
                        } else {
                           throw '\'' + requestedStream + '\' was requested, but \'' + selectedStream + '\' was selected';
                        }
                    })
                    .catch(function (err) {
                        self.streamErrors[self.streamNames.indexOf('desktop')] = err;
                        console.log('Desktop cannot be recorded: ' + err);
                        if (err.name === 'AbortError') {
                            self.numCheckedStreams = self.numStreams;
                        } else {
                            self.numCheckedStreams++;
                        }
                    });
            }
        }
    }

    start() {
        this.checkMissingStreams();
        this.takePictures(this.minMsInterval, this.maxMsInterval);
    }

    reset() {
        this.pictures[0].length = 0;
        this.pictures[1].length = 0;
    }

    streamMuted(stream) {
        for (const track of stream.getAudioTracks()) {
            if (track.muted ||
                !track.enabled ||
                track.getSettings().volume === 0) {
                return true;
            }
        }
        for (const track of stream.getVideoTracks()) {
            if (track.muted ||
                !track.enabled) {
                return true;
            }
        }
        return false;
    }

    checkStream(i) {
        const stream = this.streams[i];
        const streamName = this.streamNames[i];
        const video = this.videos[i];

        if (typeof streamName !== 'undefined' && this.mediaConf[streamName].required) {
            try {
                if (this.streamErrors[i]) {
                    throw this.streamErrors[i];
                } else if (stream === null) {
                    throw 'stream does not exist';
                } else if (!stream.active) {
                    throw 'stream is not active';
                } else if (this.streamMuted(stream)) {
                    throw 'stream is muted';
                } else if (this.ready && video && video.paused) {
                    throw 'video acquisition appears to have stopped';
                }
            } catch (e) {
                this.isMissingStreams = true;
                if (typeof this.onMissingStreamHandler === 'function') {
                    this.onMissingStreamHandler(streamName, e);
                }
            }
        }
    }

    checkMissingStreams() {
        if (!this.isMissingStreams &&
            this.numCheckedStreams === this.numStreams) {
            for (let i = 0; i < this.streams.length; i++) {
                this.checkStream(i);
            }
        }

        if (!this.isMissingStreams) {
            setTimeout(this.checkMissingStreams.bind(this), 1000);
        }
    }

    renderGif(frames) {
        if (frames.length === 0) {
            return;
        }
        const i = this.pictures.indexOf(frames);
        if (this.gifs[i] === null) {
            this.gifs[i] = new GIF({
                workers: 2,
                quality: 30,
                workerScript: Proctoring.webWorkerURL,
                width: frames[0].width,
                height: frames[0].height
            });
            const self = this;
            const gifs = this.gifs;
            gifs[i].on('finished', function(blob) {
                const handlers = self.imageHandlers[i];
                if (typeof handlers.gif.blob === 'function') {
                    handlers.gif.blob(blob);
                }
                if (typeof handlers.gif.base64 === 'function') {
                    const reader = new FileReader();
                    reader.readAsDataURL(blob);
                    reader.onloadend = function() {
                        handlers.gif.base64(reader.result);
                    }
                }
                // Stop the workers and kill the gif object
                this.abort();
                this.freeWorkers.forEach(w => w.terminate());
                gifs[gifs.indexOf(this)] = null;
            });
        }
        const gif = this.gifs[i];
        if (!gif.running) {
            for (let j = 0; j < frames.length; j++) {
                gif.addFrame(frames[j], {delay: 500});
            }
            gif.render();
        }
    }

    createVideo(stream) {
        const video = document.createElement('video');
        video.muted = true;
        video.autoplay = true;
        video.preload = 'auto';
        video.srcObject = stream;
        video.addEventListener('loadeddata', function(e) {
            if (this.paused) {
                this.play();
            }
        });
        // Try to force that video is never put to sleep
        video.addEventListener('pause', function(e) {
            this.play();
        });

        return video;
    }

    watermark(canvas, text) {
        const ctx = canvas.getContext('2d');
        const fontSize = 0.032 * canvas.width;
        ctx.font = '10px monospace' ;
        ctx.fillStyle = 'white';
        ctx.strokeStyle = 'black';
        ctx.lineWidth = 0.5;
        const metrics = ctx.measureText(text);
        const x = canvas.width - metrics.width;
        const y = canvas.height - fontSize;
        ctx.fillText(text, x, y);
        ctx.strokeText(text, x, y);
    }

    canvasToGrayscale(canvas) {
        const ctx = canvas.getContext('2d');
        const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
        const data = imageData.data;
        for (let i = 0; i < data.length; i += 4) {
            const avg = (data[i] + data[i + 1] + data[i + 2]) / 3;
            data[i]     = avg; // red
            data[i + 1] = avg; // green
            data[i + 2] = avg; // blue
        }
        ctx.putImageData(imageData, 0, 0);
    }

    isCanvasMonochrome(canvas) {
        const ctx = canvas.getContext('2d');
        const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
        const data = imageData.data;
        const firstPx = [];
        for (let i = 0; i < data.length; i += 4) {
            if (i === 0) {
                firstPx[0] = data[i];
                firstPx[1] = data[i+1];
                firstPx[2] = data[i+2];
            } else if (firstPx[0] !== data[i] ||
                       firstPx[1] !== data[i+1] ||
                       firstPx[2] !== data[i+2]) {
                return false;
            }
        }

        return true;
    }

    cloneCanvas(canvas) {
        const c = document.createElement('canvas');
        c.width = canvas.width;
        c.height = canvas.height;
        c.getContext('2d').drawImage(canvas, 0, 0, c.width, c.height);
        return c;
    }

    areCanvasEquals(canvas1, canvas2) {
        const ctx1 = canvas1.getContext('2d');
        const imageData1 = ctx1.getImageData(0, 0, canvas1.width, canvas1.height);
        const data1 = imageData1.data;
        const ctx2 = canvas2.getContext('2d');
        const imageData2 = ctx2.getImageData(0, 0, canvas2.width, canvas2.height);
        const data2 = imageData2.data;
        for (let i = 0; i < data1.length; i += 4) {
            if (data1[i] !== data2[i] ||
                data1[i+1] !== data2[i+1] ||
                data1[i+2] !== data2[i+2]) {
                return false;
            }
        }

        return true;
    }


    takeShot(stream, grayscale) {
        const i = this.streams.indexOf(stream);
        const video = this.videos[i];

        if (!video.paused) {
            const streamName = this.streamNames[i];
            const conf = this.mediaConf[streamName];
            // const height = stream.getVideoTracks()[0].getSettings().height;
            // const width = stream.getVideoTracks()[0].getSettings().width;
            const iHeight = conf.height === undefined ? video.videoHeight : conf.height;
            const iWidth = conf.width === undefined ? video.videoWidth : conf.width;
            const self = this;
            const pictures = this.pictures[i];
            const prevPicture = this.prevPictures[i];

            const canvas = document.createElement('canvas');
            canvas.width = iWidth;
            canvas.height = iHeight;
            canvas.getContext('2d').drawImage(video, 0, 0, iWidth, iHeight);

            // In the future we might be stricter about black pictures...
            // if (this.isCanvasMonochrome(canvas)) {
            //     throw 'canvas is monochrome';
            // }

            // Check that camera does not keep sending the same
            // picture over and over.
            if (streamName === 'camera' &&
                prevPicture !== null &&
                this.areCanvasEquals(canvas, prevPicture)) {
                throw 'Camera is sending the same identical picture twice.';
            }
            this.prevPictures[i] = this.cloneCanvas(canvas);

            if (grayscale) {
                this.canvasToGrayscale(canvas);
            }

            this.watermark(canvas, (new Date()).toTZISOString());

            const handlers = self.imageHandlers[i];
            if (handlers !== null) {
                if (handlers.png !== undefined) {
                    canvas.toBlob(function(blob) {
                        if (typeof handlers.png.blob === 'function') {
                            handlers.png.blob(blob);
                        }
                        if (typeof handlers.png.base64 === 'function') {
                            const reader = new FileReader();
                            reader.readAsDataURL(blob);
                            reader.onloadend = function() {
                                handlers.png.base64(reader.result);
                            }
                        }
                    }, 'image/png');
                }
                if (handlers.jpeg !== undefined) {
                    canvas.toBlob(function(blob) {
                        if (typeof handlers.jpeg.blob === 'function') {
                            handlers.jpeg.blob(blob);
                        }
                        if (typeof handlers.jpeg.base64 === 'function') {
                            const reader = new FileReader();
                            reader.readAsDataURL(blob);
                            reader.onloadend = function() {
                                handlers.jpeg.base64(reader.result);
                            }
                        }
                    }, 'image/jpeg');
                }
                if (handlers.gif !== undefined) {
                    pictures.push(canvas);
                    self.renderGif(pictures);
                }
            }
        }
    }

    takePictures(minMsInterval, maxMsInterval) {
        let interval;
        if (!this.isMissingStreams &&
            this.numCheckedStreams === this.numStreams &&
            this.numActiveStreams > 0) {
            // User already gave access to all requested streams and
            // proctoring has successfully started
            if (!this.ready) {
                // If this is the first picture we take for this
                // session, take not of this and trigger the onReady
                // handler
                if (typeof this.onReadyHandler === 'function') {
                    this.onReadyHandler();
                }
                this.ready = true;
            }
            // For every configured video stream, take a picture
            for (let i = 0; i < this.streams.length; i++) {
                try {
                    if (this.videos[i]) {
                        this.takeShot(this.streams[i],
                                      this.mediaConf[this.streamNames[i]].grayscale);
                    }
                } catch (e) {
                    this.onMissingStreamHandler(this.streamNames[i], e);
                    return;
                }
            }
            // Set the time to the next snapshot to a random interval
            interval = (Math.random() * (maxMsInterval - minMsInterval)) + minMsInterval;
        } else {
            // Not all streams are available and we cannot take
            // snapshots (yet?). Set interval one second from now.
            interval = 1000;
            console.log('Waiting for streams: ' + this.numCheckedStreams + '/' + this.numStreams + ' ready.');
        }
        if (!this.isMissingStreams) {
            // No errors, reschedule this function for the computed
            // interval
            setTimeout(this.takePictures.bind(this), interval, minMsInterval, maxMsInterval);
        } else {
            // Something went wrong and proctoring cannot proceed
            console.log('Stopping...');
        }
    }
}

// We need this trick to get the folder of this very script and build
// from there the URL to the gif worker.
const scripts = document.querySelectorAll('script');
const loc = scripts[scripts.length - 1].src;
Proctoring.webWorkerURL = loc.substring(0, loc.lastIndexOf('/')) + '/gif.worker.js';
