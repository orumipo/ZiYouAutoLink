// ZiYouAutoLink - Photoshop "Quit Application" hook.
// Photoshop runs this right before it exits; it starts the grace countdown that
// closes the font client unless another watched app is still running.
(function () {
    try {
        var base = $.getenv("LOCALAPPDATA").replace(/\\/g, "/") + "/ZiYouAutoLink";
        var f = new File(base + "/ziyou-grace.vbs");
        if (f.exists) { f.execute(); }
    } catch (e) {
    }
})();
