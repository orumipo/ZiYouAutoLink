// ZiYouAutoLink - Illustrator startup script.
//
// Install location (per Adobe's Illustrator Scripting Guide):
//   <Illustrator install dir>/Startup Scripts/
// Illustrator runs every .jsx in that folder when the application launches.
//
// Illustrator's scripting API has no notifiers (its Application object has no
// notifiers property - verified against the official object reference), so the
// quit side is handled by a tiny waiter process instead: it blocks until
// Illustrator exits and then runs the same grace countdown Photoshop uses.
//
// Paths come from the environment so this file stays pure ASCII.
(function () {
    var base = $.getenv("LOCALAPPDATA").replace(/\\/g, "/") + "/ZiYouAutoLink";

    try {
        var launch = new File(base + "/ziyou-launch.vbs");
        if (launch.exists) { launch.execute(); }
    } catch (e) {
    }

    try {
        var wait = new File(base + "/ziyou-wait-ai.vbs");
        if (wait.exists) { wait.execute(); }
    } catch (e) {
    }
})();
