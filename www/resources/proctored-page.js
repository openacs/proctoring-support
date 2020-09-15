function modalAlert(message, handler) {
    document.querySelector("#modal-messages .modal-body").innerHTML = message;
    dialog = $('#modal-messages');
    if (typeof handler == 'function') {
        dialog.on('hidden.bs.modal', handler);
    }
    dialog.modal('show');
}

function streamMuted(stream) {
    var muted = false;
    var audioTracks = stream.getAudioTracks();
    for (var i = 0; i < audioTracks.length; i++) {
        var track = audioTracks[i];
        if (track.muted ||
            track.getSettings().volume == 0) {
            muted = true;
            break;
        }
    }
    return muted;
}

function embedAudioTrackFromStream(fromStream, toStream) {
    if (fromStream == undefined) {
        return;
    }
    var audioTracks = fromStream.getAudioTracks();
    if (audioTracks.length == 0) {
        return;
    } else {
        toStream.addTrack(audioTracks[0]);
    }
    return toStream;
}

function createIframe() {
    console.log("creating iframe");
    var iframe = document.createElement("iframe");
    iframe.setAttribute("class", "embed-responsive-item");
    iframe.setAttribute("id", "proctored-iframe-" + objectId);
    iframe.addEventListener("load", function(e) {
        // Prevent loops of iframes: bring the iframe to the
        // start when we detect it would land on the very URL
        // of this page
        var parentURL = location.href + location.search;
        var iframeURL = this.contentWindow.location.href + this.contentWindow.location.search;
        if (parentURL == iframeURL) {
            this.src = objectURL;
        }
        console.log("iframe loaded");
    });
    document.querySelector("#proctored-iframe-placeholder").appendChild(iframe);
    iframe.src = objectURL;
    console.log("iframe created");
}

function createPreview() {
    var style;
    var e = document.querySelector("#preview-placeholder");
    style = !hasPreview ? "position:absolute;top:0;left:0;" : "";
    e.setAttribute("style", style);
    var canvas = document.createElement("canvas");
    style = hasPreview ? "height: 30px; width: 40px" : "height: 1px; width: 1px";
    canvas.setAttribute("style", style);
    canvas.setAttribute("id", "audio-preview");
    e.appendChild(canvas);
    new AudioWave(proctoring.streams[0], "#audio-preview");
    for (var i = 0; i < proctoring.videos.length; i++) {
        var video = proctoring.videos[i];
        var width = hasPreview ? 30 : 1;
        video.setAttribute("height", width);
        e.appendChild(video);
    }
}

var uploadQueue = [];
function scheduleUpload(name, type, blob) {
    if (type == "image" &&
        (blob == null ||
        blob.size <= blackPictureSizeThreshold)) {
        if (name == "camera") {
            modalAlert(blackPictureCameraMessage);
        } else {
            modalAlert(blackPictureDesktopMessage);
        }
    }
    var formData = new FormData();
    formData.append("name", name);
    formData.append("type", type);
    formData.append("object_id", objectId);
    formData.append("file", blob);
    formData.append("check_active_p", checkActive);
    uploadQueue.push(formData);
}

function upload() {
    if (uploadQueue.length > 0) {
        var formData = uploadQueue.shift();
        var request = new XMLHttpRequest();
        request.timeout = 10000;
        request.addEventListener("readystatechange", function () {
            if (this.readyState == 4) {
                if(this.status == 200) {
                    if (this.response == "OK") {
                        setTimeout(upload);
                    } else {
                        location.href = objectURL;
                    }
                } else {
                    uploadQueue.unshift(formData);
                    setTimeout(upload, 10000);
                }
            }
        });
        request.addEventListener("timeout", function () {
            uploadQueue.unshift(formData);
            setTimeout(upload, 10000);
        });
        request.open("POST", uploadURL);
        request.send(formData);
    } else {
        setTimeout(upload, 1000);
    }
}

function approveStartExam() {
    valid = false;
    clearError();
    var formData = new FormData();
    formData.append("object_id", objectId);
    var request = new XMLHttpRequest();
    request.timeout = 10000;
    request.addEventListener("readystatechange", function () {
        if (this.readyState == 4) {
            if(this.status == 200) {
                if (this.response == "OK") {
                    valid = true;
                } else {
                    location.href = objectURL;
                }
            } else {
                var errmsg = requestFailedMessage;
                setError(errmsg);
                setTimeout(approveStartExam, 10000);
            }
        }
    });
    request.addEventListener("timeout", function () {
        var errmsg = requestTimedOutMessage;
        setError(errmsg);
        setTimeout(approveStartExam, 10000);
    });
    request.open("POST", examinationStatementURL);
    request.send(formData);
}


var currentTab = 0; // Current tab is set to be the first tab (0)
var recheckBtn = document.querySelector("#retryBtn");
recheckBtn.addEventListener("click", function(e) {
    recheck(currentTab);
});
document.querySelector("#prevBtn").addEventListener("click", function(e) {
    nextPrev(-1);
});
document.querySelector("#nextBtn").addEventListener("click", function(e) {
    nextPrev(1);
});

var examinationStatement = document.querySelector('#examination-statement');
var deskvideo = document.querySelector('#desktop');
var camvideo = document.querySelector('#webcam');
var audio = document.querySelector('#audio');

var streams = [];
var handlers = [];
if (hasProctoring) {
    handlers.push(function () {
        clearError();
        valid = false;
        var errmsg;
        if (isMobile) {
            errmsg = mobileDevicesNotSupportedMessage;
        } else if (!navigator.mediaDevices.getUserMedia) {
            errmsg = cameraGrabbingNotSupportedMessage;
        } else if (!navigator.mediaDevices.getDisplayMedia) {
            errmsg = desktopGrabbingNotSupportedMessage;
        } else {
            valid = true
        }
        if (!valid) {
            setError(errmsg);
        }
    });
    handlers.push(function () {
        valid = false;
        clearError();
        var constraints = {
            audio: cameraConstraints.audio
        };
        navigator.mediaDevices.getUserMedia(constraints).then(stream => {
            if (streamMuted(stream)) {
                throw yourMicrophoneIsMutedMessage;
            } else {
                camvideo.srcObject = stream;
                new AudioWave(stream, "#audio");
                valid = true;
                streams[0] = stream;
            }
        }).catch(err => {
            if (err.name == "NotAllowedError") {
                err = microphonePermissionDeniedMessage;
            } else if (err.name == "NotFoundError") {
                err = microphoneNotFoundMessage;
            } else if (err.name == "NotReadableError") {
                err = microphoneNotReadableMessage;
            }
            setError(err);
        });
    });
    handlers.push(function () {
        valid = false;
        clearError();
        var constraints = {
            video: cameraConstraints.video
        };
        navigator.mediaDevices.getUserMedia(constraints).then(stream => {
            camvideo.srcObject = stream;
            camvideo.style.display = "block";
            streams[1] = stream;
            camvideo.addEventListener("play", function() {
                var canvas = document.createElement("canvas");
                canvas.width = camvideo.videoWidth;
                canvas.height = camvideo.videoHeight;
                canvas.getContext("2d").drawImage(camvideo, 0, 0, camvideo.videoWidth, camvideo.videoHeight);
                canvas.toBlob(function(blob) {
                    if (blob == null ||
                        blob.size <= blackPictureSizeThreshold) {
                        var errmsg = blackPictureCameraMessage;
                        setError(errmsg);
                    }
                }, "image/jpeg");
            });
            valid = true;
        }).catch(err => {
            if (err.name == "NotAllowedError") {
                err = cameraPermissionDeniedMessage;
            } else if (err.name == "NotFoundError") {
 	 	err = cameraNotFoundMessage;
            } else if (err.name == "NotReadableError") {
                err = cameraNotReadableMessage;
            }
            setError(err);
        });
    });
    handlers.push(function () {
        valid = false;
        clearError();
        var constraints = {
            video: desktopConstraints.video
        };
        navigator.mediaDevices.getDisplayMedia(constraints).then(stream=> {
            var requestedStream = constraints.video.displaySurface;
            var selectedStream = stream.getVideoTracks()[0].getSettings().displaySurface;
            // If user requested for a specific displaysurface
            // and browser supports it, also check that the
            // one selected is right.
            if (requestedStream == undefined ||
                (selectedStream != undefined &&
                 requestedStream == selectedStream)) {
                deskvideo.srcObject = stream;
                deskvideo.style.display = "block";
                valid = true;
                streams[2] = stream;
            } else {
                if (selectedStream != undefined) {
                    throw wrongDisplaySurfaceSelectedMessage;
                } else {
                    throw displaySurfaceNotSupportedMessage;
                }
            }
        }).catch(err => {
            if (err.name == "NotAllowedError") {
                err = desktopPermissionDeniedMessage;
            }
            setError(err);
        });
    });
}
if (hasExaminationStatement) {
    handlers.push(function () {
        var acceptButton = document.getElementById("nextBtn");
        acceptButton.innerHTML = acceptLabel;
        var clickHandler = function(e) {
            approveStartExam();
            this.removeEventListener("click", clickHandler);
        };
        acceptButton.addEventListener("click", clickHandler);
    });
}

function showTab(n) {
    // This function will display the specified tab of the form...
    var x = document.getElementsByClassName("tab");
    x[n].style.display = "block";
    //... and fix the Previous/Next buttons:
    if (n == 0) {
        document.getElementById("prevBtn").style.display = "none";
    } else {
        document.getElementById("prevBtn").style.display = "inline";
    }
    if (n == (x.length - 1)) {
        document.getElementById("nextBtn").innerHTML = submitLabel;
    } else {
        document.getElementById("nextBtn").innerHTML = nextLabel;
    }
    //... and run a function that will display the correct step indicator:
    fixStepIndicator(n);

    if (typeof handlers[n] == "function") {
        handlers[n]();
    } else {
        valid = true;
    }
}

var errorEl = document.querySelector("#error-message");
function clearError() {
    errorEl.innerHTML = "";
    retryBtn.style.display = "none";
}

function setError(errmsg) {
    // console.error(errmsg);
    errorEl.innerHTML = errmsg;
    valid = false;
    retryBtn.style.display = "inline";
}

function recheck(n) {
    handlers[n]();
}

function nextPrev(n) {
    // This function will figure out which tab to display
    var x = document.getElementsByClassName("tab");
    // Exit the function if any field in the current tab is invalid:
    if (n == 1 && !validateForm()) return false;
    // Hide the current tab:
    x[currentTab].style.display = "none";
    // Increase or decrease the current tab by 1:
    currentTab = currentTab + n;
    // if you have reached the end of the form...
    if (currentTab >= x.length) {
        // ... the form gets submitted:
        // location.href = "";
        //document.getElementById("regForm").submit();
        startExam();
        return false;
    }
    // Otherwise, display the correct tab:
    showTab(currentTab);
}

// Retreiving the stream happens asynchronously
var valid = false;
function validateForm() {
    // If the valid status is true, mark the step as finished and valid:
    if (valid) {
        document.getElementsByClassName("step")[currentTab].className += " finish";
    }
    return valid; // return the valid status
}

function fixStepIndicator(n) {
    // This function removes the "active" class of all steps...
    var i, x = document.getElementsByClassName("step");
    for (i = 0; i < x.length; i++) {
        x[i].className = x[i].className.replace(" active", "");
    }
    //... and adds the "active" class on the current step:
    x[n].className += " active";
}

var cameraConstraints = {
    video: {
        width: { max: 640 },
        height: { max: 480 }
    },
    audio: true
};
var desktopConstraints = {
    video: {
        width: 1280,
        height: 960,
        displaySurface: "monitor"
    }
};

var audioHandlers;
if (hasAudio) {
    audioHandlers = {
        auto: function(blob) {
            scheduleUpload("camera", "audio", blob);
        }
    };
}

function startExam() {
    document.querySelector("#wizard").style.display = "none";
    document.querySelector("#proctoring").style.display = "block";

    var cameraStream = embedAudioTrackFromStream(streams[0], streams[1]);
    var desktopStream = streams[2];
    var conf = {
        minMsInterval: minMsInterval,
        maxMsInterval: maxMsInterval,
        minAudioDuration: minAudioDuration,
        maxAudioDuration: maxAudioDuration,
        onMissingStreamHandler : function(streamName, errMsg) {
            modalAlert(missingStreamMessage, function() {
                location.reload();
            });
        },
        onMicrophoneTooLowHandler : function() {
            modalAlert(microphoneTooLowMessage);
        },
        onReadyHandler: function() {
            createIframe();
            createPreview();
        },
        mediaConf: {
            camera: {
                required: true,
                grayscale: true,
                width: 320,
                height: 240,
                imageHandlers: {
                    jpeg: {
                        blob: function(blob) {
                            scheduleUpload("camera", "image", blob);
                        }
                    }
                },
                audioHandlers: audioHandlers,
                stream: cameraStream
            },
            desktop: {
                required: true,
                grayscale: false,
                imageHandlers: {
                    jpeg: {
                        blob: function(blob) {
                            scheduleUpload("desktop", "image", blob);
                        }
                    }
                },
                stream: desktopStream
            }
        }
    };

    if (hasProctoring) {
        console.log("creating proctoring");
        proctoring = new Proctoring(conf);
        console.log("starting proctoring");
        proctoring.start();
        console.log("starting upload");
        upload();
        console.log("proctoring has started");
    } else {
        createIframe();
        console.log("proctoring not requested");
    }
}

window.addEventListener("load", function() {
    document.querySelector("#proctoring").style.display = "none";
    document.querySelector("#wizard").style.display = "block";
    showTab(currentTab); // Display the current tab
});
