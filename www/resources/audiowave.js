// A class implementing an audiowave that can be plugged to an audio
// MediaStream object and displayed as a canvas on the page.

class AudioWave {
    constructor(
        stream,
        canvasSelector = "canvas",
        fillStyle = 'rgb(255, 255, 255)',
        strokeStyle = 'rgb(255, 0, 0)',
        lineWidth = 2
    ) {
        this.audioCtx = new (window.AudioContext || window.webkitAudioContext)();
        this.analyser = this.audioCtx.createAnalyser();
        this.source = this.audioCtx.createMediaStreamSource(stream);
        this.source.connect(this.analyser);
        this.analyser.fftSize = 2048;
        this.bufferLength = this.analyser.frequencyBinCount;
        this.dataArray = new Uint8Array(this.bufferLength);
        this.canvas = document.querySelector(canvasSelector);
        this.canvasCtx = this.canvas.getContext("2d");
        this.fillStyle = fillStyle;
        this.strokeStyle = strokeStyle;
        this.lineWidth = lineWidth;

        this.draw();
    }

    draw() {
        var drawVisual = requestAnimationFrame(this.draw.bind(this));
        this.analyser.getByteTimeDomainData(this.dataArray);
        this.canvasCtx.fillStyle = this.fillStyle;
        this.canvasCtx.fillRect(0, 0, this.canvas.width, this.canvas.height);
        this.canvasCtx.lineWidth = this.lineWidth;
        this.canvasCtx.strokeStyle = this.strokeStyle;
        this.canvasCtx.beginPath();
        var sliceWidth = this.canvas.width * 1.0 / this.bufferLength;
        var x = 0;
        for(var i = 0; i < this.bufferLength; i++) {
            var v = this.dataArray[i] / 128.0;
            var y = v * this.canvas.height / 2;

            if(i === 0) {
                this.canvasCtx.moveTo(x, y);
            } else {
                this.canvasCtx.lineTo(x, y);
            }

            x += sliceWidth;
        }
        this.canvasCtx.lineTo(this.canvas.width, this.canvas.height/2);
        this.canvasCtx.stroke();
    }
}
