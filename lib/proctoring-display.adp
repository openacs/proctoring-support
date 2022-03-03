<if @master_p;literal@ true>
  <master>
    <property name="doc(title)">#proctoring-support.Proctoring#</property>
</if>

<style>
#fullpage {
  display: none;
  position: sticky;
  z-index: 9999;
  top: 0;
  left: 0;
  width: 100vw;
  height: 100vh;
  max-width:100%;
  background-size: contain;
  background-repeat: no-repeat no-repeat;
  background-position: center center;
  background-color: black;
}

/* The Modal (background) */
.modal {
    display: none; /* Hidden by default */
    position: fixed; /* Stay in place */
    z-index: 1; /* Sit on top */
    padding-top: 100px; /* Location of the box */
    left: 0;
    top: 0;
    width: 100%; /* Full width */
    overflow: auto; /* Enable scroll if needed */
    background-color: rgb(0,0,0); /* Fallback color */
    background-color: rgba(0,0,0,0.4); /* Black w/ opacity */
}

/* Modal Content */
.modal-content {
    background-color: #fefefe;
    margin: auto;
    padding: 20px;
    border: 1px solid #888;
    width: 80%;
}

/* The Close Button */
.close {
    color: #aaaaaa;
    float: right;
    font-size: 28px;
    font-weight: bold;
}

.close:hover,
.close:focus {
    color: #000;
    text-decoration: none;
    cursor: pointer;
}

/* Responsive events list */

* {
    box-sizing: border-box;
}

.flex-container {
    display: flex;
    flex-wrap: wrap;
    padding: 10px;
    margin-bottom:10px;
}

.flex-container[name='data'] {
    border: 3px #eee solid;
    border-radius: 8px;
}

.flex-container.flagged {
    border-color: #a94442;
}

.flex-container.unflagged {
    border-color: #3c763d;
}

.flex-container img {
    max-width:100%;
}

[class*="flex-"] {
    flex: 100%;
    margin-bottom: 10px;
}

@media only screen and (min-width: 768px) {
  /* For desktop: */
  .flex-1 {flex: 8.33%;}
  .flex-2 {flex: 16.66%;}
  .flex-3 {flex: 25%;}
  .flex-4 {flex: 33.33%;}
  .flex-5 {flex: 41.66%;}
  .flex-6 {flex: 50%;}
  .flex-7 {flex: 58.33%;}
  .flex-8 {flex: 66.66%;}
  .flex-9 {flex: 75%;}
  .flex-10 {flex: 83.33%;}
  .flex-11 {flex: 91.66%;}
  .flex-12 {flex: 100%;}
}

</style>

<!-- The Modal -->
<div id="modal" class="modal">
  <!-- Modal content -->
  <div class="modal-content">
    <span class="close">&times;</span>
    <form>
      <input name="artifact_id" type="hidden">
      <div class="form-group">
        <label for="comment">#acs-subsite.Comment#</label>
        <textarea id="comment" name="comment" class="form-control" required></textarea>
      </div>
      <div class="checkbox">
        <label>
          <input name="flag" type="checkbox">#proctoring-support.flag_artifact_label#
        </label>
      </div>
      <button type="submit" class="btn btn-default">#acs-kernel.common_Save#</button>
    </form>
  </div>
</div>
<script <if @::__csp_nonce@ not nil>nonce="@::__csp_nonce@"</if>>

    // Get references to the modal
    var modal = document.getElementById("modal");
    var modalIdElement = modal.querySelector('[name="artifact_id"]');

    document.querySelector("#modal form").addEventListener('submit', function (e) {
        e.preventDefault();
        var request = new XMLHttpRequest();
        var form = this;
        request.addEventListener("loadend", function () {
            if (this.status === 200) {
                var artifactId = modalIdElement.value;
                updateArtifactComments(artifactId, this.response);
                form.reset();
                closeModal();
                document.querySelector(".comment[data-artifact-id='" + artifactId + "']")?.focus();
            } else {
                alert(this.response);
            }
        });
        request.open("POST", '@proctoring_url@/review');
        request.send(new FormData(form));
    });

    function closeModal() {
        modal.style.display = "none";
    }
    function openReview(e) {
        var artifactId = this.getAttribute('data-artifact-id');
        modalIdElement.value = artifactId;
        modal.style.display = "block";
        modal.querySelector("#comment").focus();
    };

    // When the user clicks on <span> (x), close the modal
    document.querySelector('#modal .close').addEventListener('click', closeModal);

    // When the user clicks anywhere outside of the modal, close it
    window.addEventListener('click', function(event) {
        if (event.target == modal) {
            closeModal();
        }
    });

    function initWS(URL, onMessage) {
        if ("WebSocket" in window) {
            websocket = new WebSocket(URL);
        } else {
            websocket = new MozWebSocket(URL);
        }
        // Keepalive websocket
        websocket.onopen = function(evt) {
            setInterval(function (ws) {
                if (ws.readyState == 1) {
                    ws.send("ping");
                }
            }, 30000, this);
        };
        websocket.onmessage = onMessage;
        return websocket;
    }

    // borrowed from https://css-tricks.com/the-complete-guide-to-lazy-loading-images/
    var imageObserver;
    document.addEventListener("DOMContentLoaded", function() {
      var lazyloadImages;

      if ("IntersectionObserver" in window) {
        lazyloadImages = document.querySelectorAll(".lazy");
        imageObserver = new IntersectionObserver(function(entries, observer) {
          entries.forEach(function(entry) {
            if (entry.isIntersecting) {
              var image = entry.target;
              image.src = image.dataset.src;
              image.classList.remove("lazy");
              imageObserver.unobserve(image);
            }
          });
        });

        lazyloadImages.forEach(function(image) {
          imageObserver.observe(image);
        });
      } else {
            var lazyloadThrottleTimeout;
            lazyloadImages = document.querySelectorAll(".lazy");

            function lazyload () {
             if(lazyloadThrottleTimeout) {
               clearTimeout(lazyloadThrottleTimeout);
             }

             lazyloadThrottleTimeout = setTimeout(function() {
               var scrollTop = window.pageYOffset;
               lazyloadImages.forEach(function(img) {
                   if(img.offsetTop < (window.innerHeight + scrollTop)) {
                     img.src = img.dataset.src;
                     img.classList.remove('lazy');
                   }
               });
               if(lazyloadImages.length == 0) {
                 document.removeEventListener("scroll", lazyload);
                 window.removeEventListener("resize", lazyload);
                 window.removeEventListener("orientationChange", lazyload);
               }
             }, 20);
            }

            document.addEventListener("scroll", lazyload);
            window.addEventListener("resize", lazyload);
            window.addEventListener("orientationChange", lazyload);
      }
    })

</script>
<if @user_id@ not nil>
    <if @file@ nil>
        <h2 style="border-bottom: 1px solid #eee;">@user_name@</h2>

        <div class="clearfix">
            <!-- person details -->
            <div class="panel panel-default pull-left" style="margin-right:1em;">
                <div class="panel-heading"><b>#acs-kernel.Person#</b></div>
                <table class="table">
                    <tr>
                        <th>#acs-subsite.Last_name#:</th>
                        <td>@last_name@</td>
                    </tr>
                    <tr>
                        <th>#acs-subsite.First_names#:</th>
                        <td>@first_names@</td>
                    </tr>
                </table>
            </div>

            <div class="panel panel-default pull-left">
                <div class="panel-heading"><b>#proctoring-support.user_photo#</b></div>
                <table class="table">
                    <tr>
                        <th>#acs-subsite.Portrait#</th>
                    </tr>
                    <tr>
                        <td><img class="img-responsive" src="@portrait_url;noquote@"></td>
                    </tr>
                </table>
            </div>
        </div>

        <p>
          <a href="@back_url@" class="btn btn-default">#xowiki.back#</a>
        </p>
        <p>
          <button data-href="@bulk_unflag_url@" id="unflag-all"
             class="btn btn-success">#proctoring-support.unflag_all_label#</button>
          <button data-href="@bulk_flag_url@" id="flag-all"
             class="btn btn-danger">#proctoring-support.flag_all_label#</button>
        </p>

        <h3 style="margin-top:1em;">#proctoring-support.recordings#</h3>
        <div class="flex-container" name="filters">
          <div class="flex-2">
            <div>
              <input type="radio" name="only" value="reviewed"> #proctoring-support.reviewed_label#
              <input type="radio" name="only" value="not-reviewed"> #proctoring-support.not_reviewed_label#
            </div>
            <div>
              <input type="radio" name="only" value="flagged"> #proctoring-support.flagged_label#
              <input type="radio" name="only" value="unflagged"> #proctoring-support.unflagged_label#
            </div>
            <div>
              <input type="radio" name="only" value="all" checked> #proctoring-support.all_artifacts_label#
            </div>
          </div>
          <div class="flex-3">
            <input type="date" name="start_date"><input type="time" name="start_time"> #acs-admin.Start_time#
          </div>
          <div class="flex-3">
            <input type="date" name="end_date"><input type="time" name="end_time"> #acs-admin.End_time#
          </div>
          <div class="flex-4">
            <select name="timeframe">
              <option value=",,,"> #acs-subsite.none#</option>
              <multiple name="timeframes">
                <option value="@timeframes.start_date@,@timeframes.start_time@,@timeframes.end_date@,@timeframes.end_time@">
                  @timeframes.name@: @timeframes.start_date@ @timeframes.start_time@ - @timeframes.end_date@ @timeframes.end_time@
                </option>
              </multiple>
            </select>
            #proctoring-support.time_filter_presets_label#
          </div>
          <div>
            <span id="total-shown">@total@</span>/<span id="total">@total@</span>
          </div>
        </div>
        <script <if @::__csp_nonce@ not nil>nonce="@::__csp_nonce@"</if>>
          document.querySelector("#flag-all").addEventListener("click", function(e) {
              if (confirm(`#proctoring-support.flag_all_confirm_msg#`)) {
                  window.location = `@bulk_flag_url;literal@`;
              }
          });
          document.querySelector("#unflag-all").addEventListener("click", function(e) {
              if (confirm(`#proctoring-support.unflag_all_confirm_msg#`)) {
                  window.location = `@bulk_unflag_url;literal@`;
              }
          });

          var dateFilters = document.querySelectorAll("[name=start_date], [name=end_date], [name=start_time], [name=end_time]");
          var radioFilters = document.querySelectorAll("[name='only']");
          function isFiltered(e, filters) {
              if (filters.status === 'flagged' && !e.classList.contains('flagged')) {
                  // - flagged artifacts
                  return true;
              } else if (filters.status === 'unflagged' && !e.classList.contains('unflagged')) {
                  // - unflagged artifacts
                  return true;
              } else if (filters.status === 'reviewed' && !e.querySelector("[data-msg]")) {
                  // - artifacts with a comment
                  return true;
              } else if (filters.status === 'not-reviewed' && e.querySelector("[data-msg]")) {
                  // - artifacts without a comment
                  return true;
              }
              var timestamp = e.querySelector("[name=title]").textContent;
              if (filters.start_date !== "") {
                  var startTime = filters.start_date;
                  if (filters.start_time !== "") {
                      startTime+= " " + filters.start_time;
                  }
                  if (startTime > timestamp) {
                      return true;
                  }
              }
              if (filters.end_date !== "") {
                  var endTime = filters.end_date;
                  if (filters.end_time !== "") {
                      endTime+= " " + filters.end_time;
                  }
                  if (endTime < timestamp) {
                      return true;
                  }
              }
              return false;
          }
          function hideFiltered() {
              var total = 0;
              var totalShown = 0;
              var filters = {"status": "all"};
              for (r of radioFilters) {
                  if (r.checked) {
                      filters.status = r.value;
                  }
              }
              for (d of dateFilters) {
                  filters[d.name] = d.value;
              }
              // Hide/show artifacts according to the filter:
              for (e of document.querySelectorAll("#event-list [name='data']")) {
                  e.style.display = isFiltered(e, filters) ? 'none' : null;
                  total++;
                  if (!e.style.display) {
                      totalShown++;
                  }
              }
              document.querySelector("#total").textContent = total;
              document.querySelector("#total-shown").textContent = totalShown;
          }
          document.querySelector("select[name=timeframe]").addEventListener('change', function(e) {
              var values = this.value.split(",");
              document.querySelector("[name=start_date]").value = values[0];
              document.querySelector("[name=start_time]").value = values[1];
              document.querySelector("[name=end_date]").value = values[2];
              document.querySelector("[name=end_time]").value = values[3];
          });
          for (f of dateFilters) {
              f.addEventListener('change', function(e) {
                  document.querySelector("select[name=timeframe]").value = ",,,";
              });
          }
          for (f of document.querySelectorAll("[name=filters]")) {
              f.addEventListener('change', function(e) {
                  hideFiltered();
              });
          }
        </script>
        <div id="event-list">
          <multiple name="events">
            <div name="data" class="flex-container">
              <div class="flex-12">
                <h3 name="title">@events.timestamp@</h3>
              </div>
              <if @events.camera_url@ ne "">
                <span name="camera" class="flex-3">
                  <img class="lazy" data-src="@events.camera_url@">
                </span>
              </if>
              <if @events.desktop_url@ ne "">
                <span name="desktop" class="flex-9">
                  <img class="lazy" data-src="@events.desktop_url@">
                </span>
              </if>
              <if @events.audio_url@ ne "">
                <span name="audio" class="flex-12">
                  <audio class="lazy" data-src="@events.audio_url@" controls></audio>
                </span>
              </if>
              <div class="flex-12" name="revisions" data-revisions="@events.revisions@">
                <div name="revision" class="flex-12" style="display:none;">
                  <button class="delete"
                          data-artifact-id="@events.artifact_id@">
                    &#128465;
                  </button>
                  <span name="timestamp"></span>
                  -
                  <span name="author"></span>
                  :
                  <span name="comment"></span>
                </div>
                <button class="comment btn btn-default"
                        data-artifact-id="@events.artifact_id@">
                  #acs-subsite.Comment#
                </button>
              </div>
              <div class="flex-12">
                <button class="unflag-all btn btn-success"
                        data-artifact-id="@events.artifact_id@">
                  #proctoring-support.unflag_artifact_label#
                </button>
                <button class="flag-all btn btn-danger"
                        data-artifact-id="@events.artifact_id@">
                  #proctoring-support.flag_artifact_label#
                </button>
              </div>
            </div>
          </multiple>
        </div>

        <script <if @::__csp_nonce@ not nil>nonce="@::__csp_nonce@"</if>>
          var fullPage = document.createElement("div");
          fullPage.id = "fullpage";
          document.body.insertBefore(fullPage, document.body.firstElementChild);
          fullPage.addEventListener("click", function(e) {
              this.style.display = "none";
          });
          function clickToEnlargeImage(e) {
              if (e.target.src) {
                  fullPage.parentElement.removeChild(fullPage);
                  document.body.insertBefore(fullPage, document.body.firstElementChild);
                  fullPage.style.backgroundImage = 'url(' + e.target.src + ')';
                  fullPage.style.display = 'block';
              }
          }
          for (img of document.querySelectorAll("img.lazy")) {
              img.addEventListener("click", clickToEnlargeImage);
          }

          function updateArtifactComments(artifactId, data) {
              var button = document.
                  querySelector(".comment[data-artifact-id='" + artifactId + "']");
              if (button) {
                  var revisions = button.parentElement;
                  revisions.setAttribute("data-revisions", data);
                  renderArtifactComments(revisions);
              }
          }
          function flag(e, flag=true) {
              e.preventDefault();
              var artifactId = e.target.getAttribute('data-artifact-id');
              var request = new XMLHttpRequest();
              request.addEventListener("loadend", function () {
                  if (this.status === 200) {
                      updateArtifactComments(artifactId, this.response);
                  } else {
                      alert(this.response);
                  }
              });
              var formData = new FormData();
              formData.append('artifact_id', artifactId);
              formData.append('flag', flag);
              request.open("POST", '@proctoring_url@/review');
              request.send(formData);
          }
          function unFlag(e) {
              flag(e, false);
          }
          function deleteArtifactComment(e) {
              e.preventDefault();
              if (!confirm(`#acs-templating.Are_you_sure#`)) {
                  return
              }
              var deleteButton = e.target;
              var artifactId = deleteButton.getAttribute('data-artifact-id');
              var record = deleteButton.getAttribute("data-record");
              var request = new XMLHttpRequest();
              request.addEventListener("loadend", function () {
                  if (this.status === 200) {
                      updateArtifactComments(artifactId, this.response);
                  } else {
                      alert(this.response);
                  }
              });
              var formData = new FormData();
              formData.append('artifact_id', artifactId);
              formData.append('deleted_record', record);
              request.open("POST", '@proctoring_url@/review');
              request.send(formData);
          }
          function renderArtifactComments(e) {
              // Cleanup
              for (c of e.querySelectorAll("div[name='revision'][data-msg]")) {
                  e.removeChild(c);
              }
              var revisions = e.getAttribute('data-revisions');
              var isFlagged = false;
              var isUnflagged = false;
              if (revisions !== '') {
                  for (r of JSON.parse(decodeURIComponent(revisions))) {

                      var revision = e.firstElementChild.cloneNode(true);
                      revision.style.display = null;
                      revision.setAttribute("data-msg", true);

                      var timestamp = revision.querySelector("[name='timestamp']");
                      timestamp.style.display = null;
                      timestamp.textContent = r.timestamp;

                      var author = revision.querySelector("[name='author']");
                      author.style.display = null;
                      author.textContent = r.author;

                      var comment = revision.querySelector("[name='comment']");
                      comment.style.display = null;
                      comment.textContent = r.comment;

                      if (r.flag === 'true') {
                          isFlagged = true;
                      } else if (r.flag === 'false') {
                          isUnflagged = true;
                      }

                      var deleteButton = revision.querySelector(".delete");
                      deleteButton.setAttribute("data-record", JSON.stringify(r));
                      deleteButton.addEventListener("click", deleteArtifactComment);

                      e.insertBefore(revision, e.lastElementChild);
                  }
              }
              if (isFlagged) {
                  e.parentElement.classList.add("flagged");
              } else {
                  e.parentElement.classList.remove("flagged");
              }
              if (isUnflagged) {
                  e.parentElement.classList.add("unflagged");
              } else {
                  e.parentElement.classList.remove("unflagged");
              }
              hideFiltered();
          }
          for (e of document.querySelectorAll("[name='revisions']")) {
              renderArtifactComments(e);
          }
        </script>
        <div id="template" style="display:none;">
          <div name="data" class="flex-container">
            <div class="flex-12">
              <h3 name="title"></h3>
            </div>
            <span name="camera" class="flex-3">
              <img class="lazy" data-src="">
            </span>
            <span name="desktop" class="flex-9">
              <img class="lazy" data-src="">
            </span>
            <span name="audio" class="flex-12">
              <audio class="lazy" data-src="" controls></audio>
            </span>
            <div class="flex-12" name="revisions" data-revisions="">
              <div name="revision" class="flex-12" style="display:none;">
                <button class="delete">
                  &#128465;
                </button>
                <span name="timestamp"></span>
                -
                <span name="author"></span>
                :
                <span name="comment"></span>
              </div>
              <button class="comment btn btn-default"
                      style="display:none;"
                      data-artifact-id="">#acs-subsite.Comment#</button>
            </div>
            <div class="flex-12">
              <button class="unflag-all btn btn-success"
                      data-artifact-id="">
                #proctoring-support.unflag_artifact_label#
              </button>
              <button class="flag-all btn btn-danger"
                      data-artifact-id="">
                #proctoring-support.flag_artifact_label#
              </button>
            </div>
          </div>
        </div>
        <script <if @::__csp_nonce@ not nil>nonce="@::__csp_nonce@"</if>>
           function setEventButtonHandlers(element) {
               for (e of element.querySelectorAll(".comment")) {
                   e.addEventListener('click', openReview);
               }
               for (e of element.querySelectorAll(".flag-all")) {
                   e.addEventListener('click', flag);
               }
               for (e of element.querySelectorAll(".unflag-all")) {
                   e.addEventListener('click', unFlag);
               }
           }
           setEventButtonHandlers(document);
           initWS("@ws_url;literal@", function(e) {
               var template = document.querySelector("#template").firstElementChild;
               var eventList = document.querySelector("#event-list");
               var lastEvent = null;
               if (eventList.children.length > 0) {
                   lastEvent = eventList.children[eventList.children.length - 1];
               }

               function getFileURL(e) {
                   var fileTokens = e.file.split("/");
                   return "@user_url@&file=" + fileTokens[fileTokens.length - 1];
               }
               function createEvent(e) {
                   var event = template.cloneNode(true);
                   for (s of event.querySelectorAll("span")) {
                       s.style.display = 'none';
                   }
                   var title = event.querySelector("[name=title]");
                   var timestamp = new Date(e.timestamp * 1000);
                   // Compute the local ISO date. toISOString would
                   // return the UTC time...
                   timestamp =
                       (timestamp.getFullYear() + '').padStart(4, '0') + '-' +
                       ((timestamp.getMonth() + 1) + '').padStart(2, '0') + '-' +
                       (timestamp.getDate() + '').padStart(2, '0') + ' ' +
                       (timestamp.getHours() + '').padStart(2, '0') + ':' +
                       (timestamp.getMinutes() + '').padStart(2, '0') + ':' +
                       (timestamp.getSeconds() + '').padStart(2, '0');
                   title.textContent = timestamp;
                   var button = event.querySelector(".comment");
                   button.addEventListener('click', openReview);
                   eventList.appendChild(event);
                   return event;
               }
               function appendEvent(e) {
                   var event;
                   if (e.type !== 'audio' &&
                       lastEvent &&
                       lastEvent.querySelector("[name='" + e.name + "']")?.style.display === 'none' &&
                       lastEvent.querySelector("[name='audio']")?.style.display === 'none') {
                       event = lastEvent;
                   } else {
                       event = createEvent(e);
                   }

                   var buttons = event.querySelectorAll("[data-artifact-id]");
                   var id = buttons[0].getAttribute("data-artifact-id");
                   if (id === '' || e.name === 'camera') {
                       for (b of buttons) {
                           b.setAttribute("data-artifact-id", e.id);
                           b.style.display = null;
                       }
                       setEventButtonHandlers(event);
                   }

                   var place, element;
                   if (e.type === 'audio') {
                       place = event.querySelector("[name='audio']");
                       element = place.querySelector("audio");
                       element.setAttribute("data-src", getFileURL(e));
                   } else {
                       place = event.querySelector("[name='" + e.name + "']");
                       element = place.querySelector("img");
                       element.setAttribute("data-src", getFileURL(e));
                       element.addEventListener("click", clickToEnlargeImage);
                   }
                   place.style.display = null;
                   imageObserver.observe(element);

                   hideFiltered();
               }

               appendEvent(JSON.parse(e.data));
           });
        </script>
    </if>
</if>
<else>
  <style>
    .review-status {
        background-color:#f1f1f1;
        border: 1px black solid;
        text-align: center;
    }
    .review-status div.flagged {
        background-color:red;
    }
    .review-status div.ok {
        background-color:green;
    }
  </style>
  <div class="form-group">
    <label for="filter">#acs-kernel.common_Search#:</label>
    <input type="text" class="form-control" id="filter" value="">
  </div>

  <listtemplate name="users"></listtemplate>

  <script <if @::__csp_nonce@ not nil>nonce="@::__csp_nonce@"</if>>
    // When new artifacts are generated for this object, this websocket
    // will trigger a page reload (capped to once every 60 seconds)
    var isLoading = false;
    initWS("@ws_url@", function(e) {
        if (!isLoading) {
            isLoading = true;
            setTimeout(function() {
                if ( window.history.replaceState ) {
                    window.history.replaceState(null, null, window.location.href);
                }
                window.location = window.location.href;
            }, 60000);
        }
    });

    // Enable the bulk-action delete button only when something has
    // been selected.
    var deleteButton = document.querySelector("#users-bulk_action-1");
    if (deleteButton) {
        deleteButton.setAttribute("disabled", "");
        deleteButton.addEventListener("click", function(e) {
            if (!confirm(`#proctoring-support.delete_users_artifacts_confirm_msg#`)) {
                e.preventDefault();
                e.stopImmediatePropagation();
            }
        });
        var bulkCheckboxes = document.querySelectorAll(`
            #users-bulkaction-control,
            form[name=users] input[name=user_id]`);
        function toggleBulkActionsOnSelection(e) {
            var selected = false;
            for (i of bulkCheckboxes) {
                if (e.target.checked || i.checked) {
                    selected = true;
                    break;
                }
            }
            if (selected) {
                deleteButton.removeAttribute("disabled");
            } else {
                deleteButton.setAttribute("disabled", "");
            }
        }
        for (i of bulkCheckboxes) {
            i.checked = false;
            i.addEventListener("change", toggleBulkActionsOnSelection);
        }
    }

    // Filter the users list based on the search bar
    document.querySelector("#filter").addEventListener("keyup", function(e) {
        var visibleSelector, hiddenSelector;
        visibleSelector = "";
        var tokens = this.value.toLowerCase().split(/\s+/);
        for (var i = 0; i < tokens.length; i++) {
            if (tokens[i].length > 0) {
                visibleSelector+= '[data-filter*="' + tokens[i] + '"] ';
            }
        }

        if (visibleSelector.length == 0) {
            visibleSelector = "[data-filter]";
            hiddenSelector = "";
        } else {
            hiddenSelector = "[data-filter]:not(" + visibleSelector.trim() + ")";
        }

        for (visible of document.querySelectorAll(visibleSelector)) {
            visible.parentElement.parentElement.style.display = "";
        }

        if (hiddenSelector.length > 0) {
            // Hidden checkboxes might still be selected. If we are
            // hinding any element, we first reset them.
            for (i of (bulkCheckboxes ? bulkCheckboxes : [])) {
                i.checked = false;
            }
            for (hidden of document.querySelectorAll(hiddenSelector)) {
                hidden.parentElement.parentElement.style.display = "none";
            }
        }
    });
  </script>
</else>
