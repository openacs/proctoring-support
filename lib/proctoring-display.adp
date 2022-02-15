<if @master_p;literal@ true>
  <master>
    <property name="doc(title)">#proctoring-support.Proctoring#</property>
</if>

<script <if @::__csp_nonce@ not nil>nonce="@::__csp_nonce@"</if>>
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
<if @swa_p;literal@ true and @folder_exists_p;literal@ true>
  <p>
    <a id="delete-button" href="@delete_url@" class="btn btn-danger">@delete_label@</a>
  </p>
  <script <if @::__csp_nonce@ not nil>nonce="@::__csp_nonce@"</if>>
    document.querySelector("#delete-button").addEventListener("click", function(e) {
        if (!confirm("@delete_confirm@")) {
            e.preventDefault();
        }
    });
  </script>
</if>
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

        <p><a href="@back_url@" class="btn btn-default">#xowiki.back#</a></p>

        <h3 style="margin-top:1em;">#proctoring-support.recordings#</h3>

        <ul class="list-group" id="event-list">
          <multiple name="events">
            <li class="list-group-item" >
              <h3 name="title">@events.timestamp@</h3>

              <div name="data">
                <if @events.camera_url@ ne "">
                  <span name="camera"><img class="lazy" data-src="@events.camera_url@"></span>
                </if>
                <if @events.desktop_url@ ne "">
                  <span name="desktop"><img class="lazy" data-src="@events.desktop_url@"></span>
                </if>
                <if @events.audio_url@ ne "">
                  <span name="audio"><audio class="lazy" data-src="@events.audio_url@" controls></span>
                </if>
                <script <if @::__csp_nonce@ not nil>nonce="@::__csp_nonce@"</if>>
                </script>
              </div>
            </li>
          </multiple>
        </ul>
        <div id="template" style="display:none;">
          <li class="list-group-item" >
            <h3 name="title"></h3>
            <div name="data"></div>
          </li>
        </div>
        <script <if @::__csp_nonce@ not nil>nonce="@::__csp_nonce@"</if>>
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
                   eventList.appendChild(event);
                   return event;
               }
               function appendImage(e) {
                   var event;
                   if (lastEvent != null &&
                       lastEvent.querySelector("[name='" + e.name + "']") == null &&
                       lastEvent.querySelector("[name='audio']") == null) {
                       event = lastEvent;
                   } else {
                       event = createEvent(e);
                   }
                   var span = document.createElement("span");
                   span.setAttribute("name", e.name);
                   var img = document.createElement("img");
                   img.setAttribute("class", "lazy");
                   img.setAttribute("data-src", getFileURL(e));
                   imageObserver.observe(img);
                   span.appendChild(img);
                   event.querySelector("[name='data']").appendChild(span);
               }
               function appendAudio(e) {
                   var event = createEvent(e);
                   var span = document.createElement("span");
                   span.setAttribute("name", "audio");
                   var audio = document.createElement("audio");
                   audio.controls = true;
                   audio.setAttribute("class", "lazy");
                   audio.setAttribute("data-src", getFileURL(e));
                   imageObserver.observe(audio);
                   span.appendChild(audio);
                   event.querySelector("[name='data']").appendChild(span);
               }

               var event = JSON.parse(e.data);
               if (event.type == "audio") {
                   appendAudio(event);
               } else {
                   appendImage(event);
               }
           });
        </script>
    </if>
</if>
<else>
  <div class="form-group">
    <label for="filter">#acs-kernel.common_Search#:</label>
    <input type="text" class="form-control" id="filter">
  </div>
  <if @swa_p;literal@ true>
    <div class="btn-group">
      <span class="btn btn-default">
        <input type="checkbox" id="proctoring-bulk-all">
      </span>
      <span class="btn btn-default dropdown-toggle"
            data-toggle="dropdown"
            role="button"
            aria-expanded="false">
        #xotcl-core.Bulk_actions#<span class="caret"></span>
      </span>
      <ul class="dropdown-menu" role="menu">
        <li><a id="proctoring-bulk-delete"
               class="bin-empty">#acs-kernel.common_Delete#</a></li>
      </ul>
    </div>
  </if>
  <ul class="list-group">
    <multiple name="users">
      <li class="list-group-item" id="@users.user_id@" data-filter="@users.filter@">
        <!-- <img src="@users.portrait_url@"> -->
          <if @swa_p;literal@ true>
            <input type="checkbox"
                   class="proctoring-bulk"
                   data-user-id="@users.user_id@">
          </if>
          <a style="display:inline-block;width:95%;"
             href="@users.proctoring_url@">@users.last_name@ @users.first_names@</a>
      </li>
    </multiple>
  </ul>
  <script <if @::__csp_nonce@ not nil>nonce="@::__csp_nonce@"</if>>
    var isLoading = false;
    initWS("@ws_url@", function(e) {
        // A new user has pictures
        if (!isLoading && document.querySelector("#" + e.data.user_id) == null) {
            isLoading = true;
            setTimeout(function() {
                location.reload();
            }, 10000);
        }
    });

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

        var visible = document.querySelectorAll(visibleSelector);
        console.log(visibleSelector);
        for (var i = 0; i < visible.length; i++) {
            visible[i].style.display = "";
        }

        if (hiddenSelector.length > 0) {
            var hidden = document.querySelectorAll(hiddenSelector);
            for (var i = 0; i < hidden.length; i++) {
                hidden[i].style.display = "none";
            }
        }
    });

    var bulkSelectAllButton = document.querySelector('#proctoring-bulk-all');
    if (bulkSelectAllButton) {
        bulkSelectAllButton.addEventListener('click', function (e) {
            for (checkbox of document.querySelectorAll('.proctoring-bulk')) {
                checkbox.checked = this.checked;
            }
        });
    }

    var bulkDeleteButton = document.querySelector('#proctoring-bulk-delete');
    if (bulkDeleteButton) {
        bulkDeleteButton.addEventListener('click', function(e) {
            e.preventDefault();
            if (!confirm('#xowiki.delete_confirm#')) {
                return;
            }
            var formData = new FormData();
            formData.append('delete', true);
            formData.append('object_id', @object_id;literal@);
            for (checkbox of document.querySelectorAll('.proctoring-bulk')) {
                console.log(checkbox.checked);
                if (checkbox.checked) {
                    var userId = checkbox.getAttribute('data-user-id');
                    formData.append('user_id', userId);
                }
            }
            if (!formData.has('user_id')) {
                return;
            }
            var oReq = new XMLHttpRequest();
            function reqListener () {
                if (this.status == 200) {
                    location.reload();
                } else {
                    console.error("Page returned status " + this.status);
                }
            }
            oReq.addEventListener("load", reqListener);
            oReq.open("POST", '@base_url@');
            oReq.send(formData);
        });
    }
  </script>
</else>
