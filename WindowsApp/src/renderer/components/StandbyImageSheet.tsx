import React, { useState } from 'react';
import { StandbyImageGroup } from '../../shared/types';
import styles from './StandbyImageSheet.module.css';

interface StandbyImageSheetProps {
  standbyGroups: StandbyImageGroup[];
  selectedGroupId: string | null;
  standbyDelay: number;
  activeGroupId?: string;
  onGroupsChange: (groups: StandbyImageGroup[]) => void;
  onDelayChange: (delay: number) => void;
  onSelectedGroupChange: (id: string | null) => void;
  onClose: () => void;
}

const StandbyImageSheet: React.FC<StandbyImageSheetProps> = ({
  standbyGroups,
  selectedGroupId,
  standbyDelay,
  activeGroupId,
  onGroupsChange,
  onDelayChange,
  onSelectedGroupChange,
  onClose,
}) => {
  const [editingGroupId, setEditingGroupId] = useState<string | null>(null);

  const selectedGroup = standbyGroups.find((g) => g.id === selectedGroupId);

  // Add new group
  const handleAddGroup = () => {
    const newGroup: StandbyImageGroup = {
      id: Math.random().toString(36).substring(2, 11),
      name: `分组 ${standbyGroups.length + 1}`,
      imagePaths: [],
      enabled: true,
      startHour: 0,
      startMinute: 0,
      endHour: 23,
      endMinute: 59,
      slideInterval: 5,
    };
    const updated = [...standbyGroups, newGroup];
    onGroupsChange(updated);
    onSelectedGroupChange(newGroup.id);
  };

  // Remove group
  const handleRemoveGroup = (id: string) => {
    const updated = standbyGroups.filter((g) => g.id !== id);
    onGroupsChange(updated);
    if (selectedGroupId === id) {
      onSelectedGroupChange(updated.length > 0 ? updated[0].id : null);
    }
  };

  // Update group property
  const updateGroup = (id: string, updates: Partial<StandbyImageGroup>) => {
    const updated = standbyGroups.map((g) =>
      g.id === id ? { ...g, ...updates } : g
    );
    onGroupsChange(updated);
  };

  // Add images to selected group
  const handleAddImages = async () => {
    if (!selectedGroup) return;

    try {
      const filePaths = await window.electronAPI.openFileDialog({
        title: '选择待机图片',
        filters: [
          { name: '图片', extensions: ['png', 'jpg', 'jpeg', 'bmp', 'gif'] },
        ],
        properties: ['openFile', 'multiSelections'],
      });

      if (filePaths && filePaths.length > 0) {
        const newPaths = [...selectedGroup.imagePaths, ...filePaths];
        updateGroup(selectedGroupId!, { imagePaths: newPaths });
      }
    } catch (err) {
      console.error('Failed to open file dialog:', err);
    }
  };

  // Remove image from group
  const handleRemoveImage = (index: number) => {
    if (!selectedGroup) return;
    const newPaths = selectedGroup.imagePaths.filter((_, i) => i !== index);
    updateGroup(selectedGroupId!, { imagePaths: newPaths });
  };

  // Format time for display
  const formatTime = (hour: number, minute: number): string => {
    return `${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}`;
  };

  return (
    <div className={styles.sheetOverlay}>
      <div className={styles.sheetContent}>
        {/* Header */}
        <div className={styles.header}>
          <h2>待机图片设置</h2>
          <button className={styles.closeButton} onClick={onClose}>
            ✕
          </button>
        </div>

        {/* Global Settings */}
        <div className={styles.globalSettings}>
          <div className={styles.settingGroup}>
            <label>待机延迟 (秒)</label>
            <div className={styles.sliderContainer}>
              <input
                type="range"
                min="0"
                max="60"
                value={standbyDelay}
                onChange={(e) => onDelayChange(parseInt(e.target.value, 10))}
                className={styles.slider}
              />
              <span className={styles.sliderValue}>{standbyDelay}s</span>
            </div>
          </div>

          {activeGroupId && (
            <div className={styles.settingGroup}>
              <label>当前活跃分组</label>
              <div className={styles.activeGroup}>
                {standbyGroups.find((g) => g.id === activeGroupId)?.name ||
                  '无'}
              </div>
            </div>
          )}
        </div>

        {/* Groups List and Editor */}
        <div className={styles.mainContent}>
          {/* Group List */}
          <div className={styles.groupsList}>
            <div className={styles.groupsHeader}>
              <h3>分组列表</h3>
              <button className={styles.addButton} onClick={handleAddGroup}>
                + 添加分组
              </button>
            </div>

            <div className={styles.groupsContainer}>
              {standbyGroups.map((group) => (
                <div
                  key={group.id}
                  className={`${styles.groupItem} ${
                    selectedGroupId === group.id ? styles.selected : ''
                  }`}
                  onClick={() => onSelectedGroupChange(group.id)}
                >
                  <div className={styles.groupItemContent}>
                    <input
                      type="checkbox"
                      checked={group.enabled}
                      onChange={(e) =>
                        updateGroup(group.id, { enabled: e.target.checked })
                      }
                      onClick={(e) => e.stopPropagation()}
                      className={styles.enableCheckbox}
                    />
                    <span className={styles.groupName}>{group.name}</span>
                    <span className={styles.groupImageCount}>
                      {group.imagePaths.length} 张
                    </span>
                  </div>
                  <button
                    className={styles.deleteButton}
                    onClick={(e) => {
                      e.stopPropagation();
                      handleRemoveGroup(group.id);
                    }}
                  >
                    ×
                  </button>
                </div>
              ))}
            </div>
          </div>

          {/* Group Editor */}
          {selectedGroup && (
            <div className={styles.groupEditor}>
              <div className={styles.editorHeader}>
                <h3>编辑分组</h3>
              </div>

              {/* Group Name */}
              <div className={styles.editorSection}>
                <label>分组名称</label>
                <input
                  type="text"
                  value={selectedGroup.name}
                  onChange={(e) =>
                    updateGroup(selectedGroupId!, { name: e.target.value })
                  }
                  className={styles.textInput}
                />
              </div>

              {/* Time Range */}
              <div className={styles.editorSection}>
                <label>时间范围</label>
                <div className={styles.timeRange}>
                  <div className={styles.timeInput}>
                    <label>开始时间</label>
                    <div className={styles.timePickers}>
                      <input
                        type="number"
                        min="0"
                        max="23"
                        value={selectedGroup.startHour}
                        onChange={(e) =>
                          updateGroup(selectedGroupId!, {
                            startHour: parseInt(e.target.value, 10),
                          })
                        }
                        className={styles.timePickerInput}
                      />
                      <span>:</span>
                      <input
                        type="number"
                        min="0"
                        max="59"
                        value={selectedGroup.startMinute}
                        onChange={(e) =>
                          updateGroup(selectedGroupId!, {
                            startMinute: parseInt(e.target.value, 10),
                          })
                        }
                        className={styles.timePickerInput}
                      />
                    </div>
                  </div>

                  <div className={styles.timeInput}>
                    <label>结束时间</label>
                    <div className={styles.timePickers}>
                      <input
                        type="number"
                        min="0"
                        max="23"
                        value={selectedGroup.endHour}
                        onChange={(e) =>
                          updateGroup(selectedGroupId!, {
                            endHour: parseInt(e.target.value, 10),
                          })
                        }
                        className={styles.timePickerInput}
                      />
                      <span>:</span>
                      <input
                        type="number"
                        min="0"
                        max="59"
                        value={selectedGroup.endMinute}
                        onChange={(e) =>
                          updateGroup(selectedGroupId!, {
                            endMinute: parseInt(e.target.value, 10),
                          })
                        }
                        className={styles.timePickerInput}
                      />
                    </div>
                  </div>
                </div>
              </div>

              {/* Slide Interval */}
              <div className={styles.editorSection}>
                <label>幻灯片间隔 (秒)</label>
                <div className={styles.sliderContainer}>
                  <input
                    type="range"
                    min="2"
                    max="30"
                    value={selectedGroup.slideInterval}
                    onChange={(e) =>
                      updateGroup(selectedGroupId!, {
                        slideInterval: parseInt(e.target.value, 10),
                      })
                    }
                    className={styles.slider}
                  />
                  <span className={styles.sliderValue}>
                    {selectedGroup.slideInterval}s
                  </span>
                </div>
              </div>

              {/* Images Section */}
              <div className={styles.editorSection}>
                <div className={styles.imagesHeader}>
                  <label>图片列表</label>
                  <button
                    className={styles.addImageButton}
                    onClick={handleAddImages}
                  >
                    + 添加图片
                  </button>
                </div>

                <div className={styles.imageGrid}>
                  {selectedGroup.imagePaths.map((imagePath, index) => (
                    <div key={index} className={styles.imageItem}>
                      <img src={imagePath} alt={`Image ${index}`} />
                      <button
                        className={styles.removeImageButton}
                        onClick={() => handleRemoveImage(index)}
                      >
                        ✕
                      </button>
                    </div>
                  ))}
                </div>

                {selectedGroup.imagePaths.length === 0 && (
                  <div className={styles.emptyImageList}>
                    点击 "添加图片" 按钮来添加待机图片
                  </div>
                )}
              </div>
            </div>
          )}

          {!selectedGroup && standbyGroups.length > 0 && (
            <div className={styles.noSelection}>选择一个分组来编辑</div>
          )}

          {standbyGroups.length === 0 && (
            <div className={styles.emptyState}>
              暂无分组，点击 "添加分组" 创建第一个分组
            </div>
          )}
        </div>

        {/* Footer */}
        <div className={styles.footer}>
          <button className={styles.closeButton} onClick={onClose}>
            关闭
          </button>
        </div>
      </div>
    </div>
  );
};

export default StandbyImageSheet;
