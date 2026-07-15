import React, { useEffect, useRef } from "react";

const AgrhiBackground = () => {
  const videoRef = useRef(null);
  const containerRef = useRef(null);

  useEffect(() => {
    const video = videoRef.current;
    video.muted = true;
    video.loop = true;
    video.preload = "auto";
    video.playsInline = true;
    video.playbackRate = 0.75; // 🐌 0.75x SPEED

    const playVideo = () => {
      video.play().catch((e) => {
        console.log("Autoplay prevented:", e);
        document.addEventListener("click", () => video.play(), { once: true });
        document.addEventListener("touchstart", () => video.play(), {
          once: true,
        });
      });
    };

    video.addEventListener("loadeddata", playVideo);

    return () => {
      video.pause();
      video.removeEventListener("loadeddata", playVideo);
    };
  }, []);

  return (
    <div
      ref={containerRef}
      style={{
        position: "fixed",
        top: 0,
        left: 0,
        zIndex: -1,
        width: "100vw",
        height: "100vh",
        background: "transparent",
        pointerEvents: "none",
        overflow: "hidden",
      }}
    >
      <video
        ref={videoRef}
        src="/bg_video.mp4"
        style={{
          width: "100%",
          height: "100%",
          objectFit: "cover",
          objectPosition: "center",
        }}
      />
    </div>
  );
};

export default AgrhiBackground;
