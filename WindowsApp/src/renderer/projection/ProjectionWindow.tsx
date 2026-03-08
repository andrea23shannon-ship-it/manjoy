import React, { useRef, useEffect, useState } from 'react';
import { AnimationRenderer } from './AnimationRenderer';
import {
  LyricLine,
  LyricsStyle,
  PeerMessage,
  PeerMessageType,
  defaultStyle,
} from '../../shared/types';

interface ProjectionState {
  lyrics: LyricLine[];
  currentLineIndex: number;
  lineProgress: number;
  isPlaying: boolean;
  style: LyricsStyle;
}

const ProjectionWindow: React.FC = () => {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const rendererRef = useRef<AnimationRenderer | null>(null);
  const [state, setState] = useState<ProjectionState>({
    lyrics: [],
    currentLineIndex: -1,
    lineProgress: 0,
    isPlaying: false,
    style: defaultStyle,
  });

  // Initialize renderer and set up canvas
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    // Initialize AnimationRenderer
    const renderer = new AnimationRenderer(canvas, state.style);
    rendererRef.current = renderer;

    // Resize canvas to fill window
    const resizeCanvas = () => {
      canvas.width = window.innerWidth;
      canvas.height = window.innerHeight;
    };

    resizeCanvas();
    window.addEventListener('resize', resizeCanvas);

    // Start animation loop (AnimationRenderer has its own internal loop)
    renderer.start();

    return () => {
      window.removeEventListener('resize', resizeCanvas);
      renderer.stop();
    };
  }, []);

  // Update renderer when state changes
  useEffect(() => {
    if (rendererRef.current) {
      rendererRef.current.setState(
        state.lyrics,
        state.currentLineIndex,
        state.lineProgress,
        state.isPlaying
      );
    }
  }, [state.lyrics, state.currentLineIndex, state.lineProgress, state.isPlaying]);

  // Update style
  useEffect(() => {
    if (rendererRef.current) {
      rendererRef.current.setStyle(state.style);
    }
  }, [state.style]);

  // Subscribe to peer messages from main process
  useEffect(() => {
    if (!window.electronAPI) {
      console.warn('electronAPI not available in projection window');
      return;
    }

    // Handle peer messages
    window.electronAPI.onPeerMessage((message: any) => {
      switch (message.type) {
        case PeerMessageType.SongLoaded:
          if (message.payload) {
            setState((prev) => ({
              ...prev,
              lyrics: message.payload.lyrics || [],
              currentLineIndex: 0,
              lineProgress: 0,
            }));
          }
          break;

        case PeerMessageType.PlaybackSync:
          if (message.payload) {
            setState((prev) => ({
              ...prev,
              isPlaying: message.payload.isPlaying ?? prev.isPlaying,
            }));
          }
          break;

        case PeerMessageType.LineChanged:
          if (message.payload) {
            setState((prev) => ({
              ...prev,
              currentLineIndex: message.payload.lineIndex ?? prev.currentLineIndex,
              lineProgress: message.payload.lineProgress ?? prev.lineProgress,
            }));
          }
          break;

        default:
          break;
      }
    });

    // Handle style updates (from main window)
    if (window.electronAPI.onStyleUpdated) {
      window.electronAPI.onStyleUpdated((style: LyricsStyle) => {
        setState((prev) => ({
          ...prev,
          style,
        }));
      });
    }
  }, []);

  return (
    <canvas
      ref={canvasRef}
      style={{
        width: '100%',
        height: '100%',
        display: 'block',
        backgroundColor: '#000000',
      }}
    />
  );
};

export default ProjectionWindow;
