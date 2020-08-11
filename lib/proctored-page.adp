<master>
  <property name="show_header">0</property>
  <property name="side_menu">0</property>
  <property name="show_title">0</property>
  <property name="show_community_title">0</property>

  <script src="/resources/proctoring-support/gif.js"></script>
  <script src="/resources/proctoring-support/proctoring.js"></script>
  <script src="/resources/proctoring-support/audiowave.js"></script>
  <link rel="stylesheet" href="/resources/proctoring-support/proctored-page.css">

  <!-- Alert/Error messages -->
  <div class="modal fade" id="modal-messages" tabindex="-1" role="dialog" aria-labelledby="modal-messages-title" aria-hidden="true">
    <div class="modal-dialog" role="document">
      <div class="modal-content">
        <div class="modal-body"></div>
        <div class="modal-footer">
          <button type="button" class="btn btn-secondary" data-dismiss="modal" data-backdrop="static" data-keyboard="false">OK</button>
        </div>
      </div>
    </div>
  </div>

  <div id="wizard">
    <h1>#xowf.menu-New-App-OnlineExam#</h1>

    <!-- One "tab" for each step in the form: -->
    <if @examination_statement_p;literal@ true>
      <div class="tab">
        <div id="examination-statement">@msg.exam_mode;literal@</div>
      </div>
    </if>
    <if @proctoring_p;literal@ true>
      <div class="tab">
        <div>@msg.proctoring_accept@</div>
      </div>
      <div class="tab">
        <h3>#proctoring-support.grant_access_to_microphone_title#</h3>
        <div>#proctoring-support.grant_access_to_microphone_msg#</div>
        <canvas id="audio" style="height: 100px; width: 100%"></canvas>
      </div>
      <div class="tab">
        <h3>#proctoring-support.grant_access_to_camera_title#</h3>
        <div>#proctoring-support.grant_access_to_camera_msg#</div>
        <video class="wizard-video" width="640" id="webcam" autoplay playsinline muted="false" volume=0></video>
      </div>
      <div class="tab">
        <h3>#proctoring-support.grant_access_to_desktop_title#</h3>
        <div>#proctoring-support.grant_access_to_desktop_msg#</div>
        <video class="wizard-video" width="640" id="desktop" autoplay playsinline muted="false" volume=0></video>
      </div>
    </if>
    <div id="error-message" class="text-danger"></div>
    <div style="overflow:auto;">
      <div style="float:right;">
        <button class="btn btn-secondary" type="button" id="prevBtn">#acs-kernel.common_Previous#</button>
        <button class="btn btn-secondary" type="button" id="retryBtn">#proctoring-support.check_again#</button>
        <button class="btn btn-secondary" type="button" id="nextBtn">#acs-kernel.common_Next#</button>
      </div>
    </div>
    <!-- Circles which indicates the steps of the form: -->
    <div id="steps">
      <if @examination_statement_p;literal@ true>
        <span class="step"></span>
      </if>
      <if @proctoring_p;literal@ true>
        <span class="step"></span>
        <span class="step"></span>
        <span class="step"></span>
        <span class="step"></span>
      </if>
    </div>
  </div>

  <div id="proctoring">
    <div class="row info_proctoring">
      <bold>@msg.proctoring_banner@</bold>
      <div id="preview-placeholder"></div>
    </div>

    <div id="proctored-iframe-placeholder" class="embed-responsive embed-responsive-16by9"></div>
  </div>

  <script <if @::__csp_nonce@ not nil>nonce="@::__csp_nonce@"</if>>
    var objectId = "@object_id;literal@";
    var objectURL = "@object_url;literal@";
    var uploadURL = "@upload_url;literal@";
    var hasExaminationStatement = @examination_statement_p;literal@;
    var examinationStatementURL = "@examination_statement_url;literal@";
    var hasPreview = @preview_p;literal@;
    var hasProctoring = @proctoring_p;literal@;
    var hasAudio = @audio_p;literal@;
    var minMsInterval = @min_ms_interval;literal@;
    var maxMsInterval = @max_ms_interval;literal@;
    var minAudioDuration = @min_audio_duration;literal@;
    var maxAudioDuration = @max_audio_duration;literal@;
    var missingStreamMessage = "@msg.missing_stream@";
    var blackPictureCameraMessage = "@msg.black_picture_camera;noquote@";
    var blackPictureDesktopMessage = "@msg.black_picture_desktop;noquote@";
    var requestFailedMessage = "@msg.request_failed@";
    var requestTimedOutMessage = "@msg.request_timeout@";
    var audioGrabbingNotSupportedMessage = "@msg.audio_grabbing_not_supported;noquote@";
    var cameraGrabbingNotSupportedMessage = "@msg.camera_grabbing_not_supported;noquote@";
    var desktopGrabbingNotSupportedMessage = "@msg.desktop_grabbing_not_supported;noquote@";
    var yourMicrophoneIsMutedMessage = "@msg.your_microphone_is_muted;noquote@";
    var microphonePermissionDeniedMessage = "@msg.microphone_permission_denied;noquote@";
    var cameraPermissionDeniedMessage = "@msg.camera_permission_denied;noquote@";
    var desktopPermissionDeniedMessage = "@msg.desktop_permission_denied;noquote@";
    var microphoneNotFoundMessage = "@msg.microphone_not_found;noquote@";
    var microphoneNotReadableMessage = "@msg.microphone_not_readable;noquote@";
    var cameraNotReadableMessage = "@msg.camera_not_readable;noquote@";
    var wrongDisplaySurfaceSelectedMessage = "@msg.wrong_display_surface_selected;noquote@";
    var displaySurfaceNotSupportedMessage = "@msg.display_surface_not_supported;noquote@";
    var mobileDevicesUnsupportedMessage = "@msg.mobile_devices_not_supported@";
    var isMobile = @mobile_p;literal@;
    var nextLabel = "#acs-kernel.common_Next#";
    var submitLabel = "#proctoring-support.wizard_finish#";
  </script>
  <script src="/resources/proctoring-support/proctored-page.js"></script>
