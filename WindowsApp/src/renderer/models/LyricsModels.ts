import {
  PeerMessage,
  LyricLine,
  StandbyImageGroup,
} from '../../shared/types';

// ===== PEER MESSAGE DECODING =====
export function decodePeerMessage(raw: any): PeerMessage {
  // If it's already a PeerMessage object, return it
  if (raw && typeof raw === 'object' && 'type' in raw) {
    return raw as PeerMessage;
  }

  // If it has a payload string that needs base64 decoding
  if (raw && typeof raw === 'object' && 'payloadBase64' in raw) {
    try {
      const decoded = atob(raw.payloadBase64);
      const payload = JSON.parse(decoded);
      return {
        type: raw.type,
        payload,
      };
    } catch (error) {
      console.error('Failed to decode peer message:', error);
      return {
        type: 'error',
        payload: { error: 'Failed to decode message' },
      };
    }
  }

  return raw as PeerMessage;
}

// ===== TIME FORMATTING =====
export function formatTime(seconds: number): string {
  if (!isFinite(seconds) || seconds < 0) {
    return '0:00';
  }

  const totalSeconds = Math.floor(seconds);
  const minutes = Math.floor(totalSeconds / 60);
  const secs = totalSeconds % 60;

  return `${minutes}:${secs.toString().padStart(2, '0')}`;
}

// ===== LINE STATE ENUM =====
export enum LineState {
  PAST = 'past',
  CURRENT = 'current',
  NEXT = 'next',
  UPCOMING = 'upcoming',
}

export function getLineState(lineIndex: number, currentIndex: number): LineState {
  if (lineIndex < currentIndex) {
    return LineState.PAST;
  } else if (lineIndex === currentIndex) {
    return LineState.CURRENT;
  } else if (lineIndex === currentIndex + 1) {
    return LineState.NEXT;
  } else {
    return LineState.UPCOMING;
  }
}

// ===== VISIBLE LINES CALCULATION =====
export interface VisibleLine extends LyricLine {
  state: LineState;
}

export function getVisibleLines(
  lyrics: LyricLine[],
  currentIndex: number,
  visibleLineCount: number = 5
): VisibleLine[] {
  if (lyrics.length === 0) {
    return [];
  }

  const startIndex = Math.max(0, currentIndex - 2);
  const endIndex = Math.min(lyrics.length, currentIndex + visibleLineCount - 2);

  const visible: VisibleLine[] = [];
  for (let i = startIndex; i < endIndex; i++) {
    visible.push({
      ...lyrics[i],
      state: getLineState(i, currentIndex),
    });
  }

  return visible;
}

// ===== STANDBY GROUP SELECTION =====
export function getActiveStandbyGroup(
  groups: StandbyImageGroup[],
  now: number
): StandbyImageGroup | null {
  if (groups.length === 0) {
    return null;
  }

  // Get current hour and minute
  const currentDate = new Date(now);
  const currentHour = currentDate.getHours();
  const currentMinute = currentDate.getMinutes();

  // Find the group whose time range contains current time
  for (const group of groups) {
    if (!group.enabled) continue;

    // Check if current time falls within the group's time range
    const startTotalMinutes = group.startHour * 60 + group.startMinute;
    const endTotalMinutes = group.endHour * 60 + group.endMinute;
    const currentTotalMinutes = currentHour * 60 + currentMinute;

    // Handle case where end time is next day (e.g., 23:00 to 06:00)
    if (startTotalMinutes <= endTotalMinutes) {
      if (currentTotalMinutes >= startTotalMinutes && currentTotalMinutes < endTotalMinutes) {
        return group;
      }
    } else {
      if (currentTotalMinutes >= startTotalMinutes || currentTotalMinutes < endTotalMinutes) {
        return group;
      }
    }
  }

  return null;
}

// ===== ANIMATION FRAME HELPER =====
export function calculateLineProgress(
  currentTime: number,
  currentLine: LyricLine | null,
  nextLine: LyricLine | null
): number {
  if (!currentLine || !nextLine) {
    return 0;
  }

  const startTime = currentLine.time;
  const endTime = nextLine.time;

  if (endTime <= startTime) {
    return 0;
  }

  const elapsed = currentTime - startTime;
  const duration = endTime - startTime;

  return Math.max(0, Math.min(1, elapsed / duration));
}

// ===== NEAREST LINE FINDER =====
export function getNearestLineIndex(lyrics: LyricLine[], currentTime: number): number {
  if (lyrics.length === 0) {
    return 0;
  }

  // Binary search for the line that matches current time
  let left = 0;
  let right = lyrics.length - 1;

  while (left < right) {
    const mid = Math.floor((left + right + 1) / 2);
    if (lyrics[mid].time <= currentTime) {
      left = mid;
    } else {
      right = mid - 1;
    }
  }

  return left;
}

// ===== LYRICS VALIDATION =====
export function validateLyrics(lyrics: LyricLine[]): boolean {
  if (!Array.isArray(lyrics) || lyrics.length === 0) {
    return false;
  }

  for (const line of lyrics) {
    if (
      typeof line.text !== 'string' ||
      typeof line.time !== 'number' ||
      line.time < 0
    ) {
      return false;
    }
  }

  // Check that times are monotonically increasing (or equal)
  for (let i = 1; i < lyrics.length; i++) {
    if (lyrics[i].time < lyrics[i - 1].time) {
      return false;
    }
  }

  return true;
}

// ===== DURATION CALCULATION =====
export function getTotalDuration(lyrics: LyricLine[]): number {
  if (lyrics.length === 0) {
    return 0;
  }

  const lastLine = lyrics[lyrics.length - 1];
  // LyricLine doesn't have duration field, so add a default 3 seconds for the last line display
  return lastLine.time + 3;
}

// ===== PROGRESS PERCENTAGE =====
export function getProgressPercentage(currentTime: number, totalDuration: number): number {
  if (totalDuration <= 0) {
    return 0;
  }

  return Math.max(0, Math.min(1, currentTime / totalDuration));
}
