use strict;
use warnings;
use JSON::PS;

my $Data = {};

for (
  ["animationend", "webkitAnimationEnd"],
  ["animationiteration", "webkitAnimationIteration"],
  ["animationstart", "webkitAnimationStart"],
  ["transitionend", "webkitTransitionEnd"],
) {
  $Data->{event_types}->{$_->[0]}->{legacy} = $_->[1];
}

my @create = qw(
      animationevent AnimationEvent
      beforeunloadevent BeforeUnloadEvent
      closeevent CloseEvent
      compositionevent CompositionEvent
      customevent CustomEvent
      devicemotionevent DeviceMotionEvent
      deviceorientationevent DeviceOrientationEvent
      dragevent DragEvent
      errorevent ErrorEvent
      event Event
      events Event
      focusevent FocusEvent
      hashchangeevent HashChangeEvent
      htmlevents Event
      idbversionchangeevent IDBVersionChangeEvent
      keyboardevent KeyboardEvent
      messageevent MessageEvent
      mouseevent MouseEvent
      mouseevents MouseEvent
      pagetransitionevent PageTransitionEvent
      popstateevent PopStateEvent
      progressevent ProgressEvent
      storageevent StorageEvent
      svgevents Event
      svgzoomevent SVGZoomEvent
      svgzoomevents SVGZoomEvent
      textevent CompositionEvent
      touchevent TouchEvent
      trackevent TrackEvent
      transitionevent TransitionEvent
      uievent UIEvent
      uievents UIEvent
      webglcontextevent WebGLContextEvent
      wheelevent WheelEvent
);
while (@create) {
  my $string = shift @create;
  my $interface = shift @create;
  $Data->{create_event_string}->{$string} = $interface;
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
