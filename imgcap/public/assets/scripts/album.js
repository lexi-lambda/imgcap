'use strict';

var scheduledLayoutUpdate = null;

// Recalculates the album layout based on element size and scroll position, then
// applies the layout to the page. The layout algorithm is designed to
// synchronize the scroll positions of both columns while keeping as much
// content from the “current” position on screen at a time.
function updateLayout() {
  var viewportHeight = $(window).height()
    // the elements of each column
    , $images = $('.album--image')
    , $descriptions = $('.album--description')
    // the current browser scroll position
    , currentScroll = $(window).scrollTop() // Math.max(0, $(window).scrollTop())
    // accumulators that keep track of how far down we need to scroll each column
    , accImageOffset = 0
    , accDescriptionOffset = 0
    // an accumulator that keeps track of the total size of the page
    , accPageHeight = 0
    // a flag that is set to ‘true’ when we’ve determined the final values of
    // accImageOffset and accDescriptionOffset so that we don’t update those
    // any further
    , accScrollLocked = false;

  $images.each(function (i) {
      // the current element from each column for the row we’re looking at
    var $image = $(this)
      , $description = $descriptions.eq(i)
      , $shades = $image.find('.album--shade')
                    .add($description.find('.album--shade'))
      // the height of each element, including the margin
      , imageHeight = $image.outerHeight(true)
      , descriptionHeight = $description.outerHeight(true)
      // the largest of the two heights
      , biggestHeight = Math.max(imageHeight, descriptionHeight);

    // perform calculation of column positions if we haven’t already determined them
    if (!accScrollLocked) {
      if (currentScroll < 0) {
        // the scroll position can be negative in safari (due to “bouncy”
        // scroll acceleration), so handle that case
        accImageOffset = currentScroll;
        accDescriptionOffset = currentScroll;
        accScrollLocked = true;
      } else if (currentScroll >= accPageHeight && currentScroll < accPageHeight + biggestHeight) {
        // if the current browser scroll position is within the current row, then
        // we should calculate the final position of the columns to position the
        // user within the current row
          // the scroll position within the current row
        var currentSectionOffset = currentScroll - accPageHeight
          // the number of pixels before the scroll position will be within the next row
          , currentSectionRemaining = biggestHeight - currentSectionOffset;
        // calculate how much to position the columns to align the user part of
        // the way through the current row
        if (currentSectionRemaining <= imageHeight) { accImageOffset += imageHeight - currentSectionRemaining; }
        if (currentSectionRemaining <= descriptionHeight) { accDescriptionOffset += descriptionHeight - currentSectionRemaining; }
        accScrollLocked = true;
      } else {
        // otherwise, just advance the columns to skip the current row entirely
        accImageOffset += imageHeight;
        accDescriptionOffset += descriptionHeight;
      }
    }

    // adjust the opacity of the shades based on how far away they are from
    // becoming the current row
    (function () {
      var shadeLimit = viewportHeight * 0.25
        , shadeDuration = viewportHeight
        , opacity = (accPageHeight - currentScroll - shadeLimit) / shadeDuration
        , clampedOpacity = Math.max(0, Math.min(opacity, 0.35));
      $shades.css('opacity', clampedOpacity);
    })();

    // the total page height is the sum of all the largest element heights
    accPageHeight += biggestHeight;
  });

  // actually apply the resulting layout information to the page
  if (scheduledLayoutUpdate) { window.cancelAnimationFrame(scheduledLayoutUpdate); }
  scheduledLayoutUpdate = window.requestAnimationFrame(function () {
    // add a bit of padding to the end of the page so that the user can scroll
    // the final row to the top of the viewport, but no further
    var imageHeight = $images.last().outerHeight(true)
      , descriptionHeight = $descriptions.last().outerHeight(true)
      , biggestHeight = Math.max(imageHeight, descriptionHeight)
      , pagePadding = Math.max(0, viewportHeight - biggestHeight);
    $('body').css('height', accPageHeight + pagePadding);
    $('.album--images').css('top', -accImageOffset);
    $('.album--descriptions').css('top', -accDescriptionOffset);
  });
}

$(updateLayout);
$(window).on('load', updateLayout);
$(window).resize(updateLayout);
$(window).scroll(updateLayout);
