---
name: camera-block
description: Наш общий React-блок камеры CameraBlock.jsx — полноэкранное окно для съёмки фото и записи видео с камеры телефона/ПК (getUserMedia, MediaRecorder), языки ru/en/he/ar с RTL. Используй, когда в любом проекте нужно сфотографировать, снять видео, открыть камеру или добавить кнопку «сделать фото».
---

# CameraBlock — общий блок камеры

Готовый эталонный компонент. Не пиши камеру с нуля: создай в проекте файл `src/components/CameraBlock.jsx` с кодом ниже **без изменений логики**; адаптировать можно только тексты (`camText`) и цвета в `css`.

## Как подключить

```jsx
import CameraBlock from './components/CameraBlock';

{showCam && (
  <CameraBlock
    lang={lang}                                   // 'ru' | 'en' | 'he' | 'ar' (he/ar — RTL)
    onCapturePhoto={(dataUrl) => { setPhoto(dataUrl); setShowCam(false); }}   // JPEG data:URL, качество 0.95
    onCaptureVideo={(blobUrl) => { setVideo(blobUrl); setShowCam(false); }}   // blob: URL
    onClose={() => setShowCam(false)}
  />
)}
```

## Что важно знать
- Нужен **HTTPS** (или localhost), иначе браузер не даст доступ к камере.
- Камера по умолчанию задняя (`facingMode: 'environment'`), до 1920×1080, со звуком.
- Поток камеры освобождается при закрытии окна, в том числе если закрыли во время запроса доступа.
- Видео отдаётся как `blob:` URL. Для загрузки на сервер: `const blob = await (await fetch(url)).blob()`, потом `FormData`. Когда ссылка больше не нужна — `URL.revokeObjectURL(url)`.
- Формат видео зависит от браузера (Chrome — webm, Safari — mp4); тип берётся из `recorder.mimeType`.
- Стили встроены в компонент (классы `cam-*`), отдельный CSS не нужен. Окно поверх всего (`z-index: 9999`).
- Если в проекте есть общий i18n (skill `i18n-block`), тексты `camText` можно перенести туда, ключи `camera.*`.

## Код: `CameraBlock.jsx`

```jsx
import { useRef, useState, useEffect } from 'react';

const camText = {
    ru: { photo: 'Фото', video: 'Видео', stop: 'Остановить', close: 'Закрыть', noAccess: 'Нет доступа к камере/микрофону.' },
    en: { photo: 'Photo', video: 'Video', stop: 'Stop', close: 'Close', noAccess: 'No access to camera/microphone.' },
    he: { photo: 'צילום', video: 'וידאו', stop: 'עצור', close: 'סגור', noAccess: 'אין גישה למצלמה/מיקרופון.' },
    ar: { photo: 'صورة', video: 'فيديو', stop: 'إيقاف', close: 'إغلاق', noAccess: 'لا يوجد وصول إلى الكاميرا/الميكروفون.' },
};

const css = `
.cam-ov{position:fixed;inset:0;background:rgba(0,0,0,.92);display:flex;flex-direction:column;align-items:center;justify-content:center;z-index:9999;padding:16px;box-sizing:border-box}
.cam-x{position:absolute;top:max(14px,env(safe-area-inset-top));inset-inline-end:14px;width:44px;height:44px;border-radius:50%;border:none;background:rgba(255,255,255,.16);color:#fff;display:flex;align-items:center;justify-content:center;cursor:pointer}
.cam-fr{position:relative;width:min(84vw,480px)}
.cam-fr video{display:block;width:100%;max-height:58vh;object-fit:cover;border-radius:12px;background:#000}
.cam-rec{position:absolute;top:10px;inset-inline-end:10px;background:#d63c3c;color:#fff;padding:4px 10px;border-radius:20px;font-weight:700;font-size:13px;animation:cam-blink 1s infinite}
.cam-bar{margin-top:22px;display:flex;gap:28px;align-items:center;justify-content:center}
.cam-b{width:64px;height:64px;border-radius:50%;border:3px solid rgba(255,255,255,.85);display:flex;align-items:center;justify-content:center;cursor:pointer;color:#fff;padding:0}
.cam-b.ph{background:#1f7a4f}
.cam-b.vd{background:transparent}
.cam-b.vd i{width:24px;height:24px;border-radius:50%;background:#d63c3c}
.cam-b.st{background:transparent}
.cam-b.st i{width:22px;height:22px;border-radius:4px;background:#d63c3c}
.cam-err{color:#d63c3c;padding:20px;background:#fff;border-radius:8px}
@keyframes cam-blink{50%{opacity:0}}
`;

export default function CameraBlock({ onCapturePhoto, onCaptureVideo, onClose, lang = 'ru' }) {
    const t = camText[lang] || camText.ru;
    const dir = lang === 'he' || lang === 'ar' ? 'rtl' : 'ltr';
    const videoRef = useRef(null);
    const canvasRef = useRef(null);
    const mediaRecorderRef = useRef(null);
    const chunksRef = useRef([]);
    const streamRef = useRef(null);
    
    const [error, setError] = useState('');
    const [isRecording, setIsRecording] = useState(false);
    const [stream, setStream] = useState(null);

    useEffect(() => {
        let cancelled = false;
        async function startCamera() {
            try {
                const s = await navigator.mediaDevices.getUserMedia({
                    video: {
                        facingMode: 'environment',
                        width: { ideal: 1920 },
                        height: { ideal: 1080 }
                    },
                    audio: true
                });
                // Окно закрыли, пока камера запрашивалась — сразу освобождаем поток
                if (cancelled) {
                    s.getTracks().forEach(track => track.stop());
                    return;
                }
                streamRef.current = s;
                setStream(s);
                if (videoRef.current) videoRef.current.srcObject = s;
            } catch (err) {
                setError(t.noAccess);
            }
        }
        startCamera();
        return () => {
            cancelled = true;
            // Берём поток из ref, а не из state: в замыкании state здесь всегда null
            if (streamRef.current) {
                streamRef.current.getTracks().forEach(track => track.stop());
                streamRef.current = null;
            }
        };
    }, []);

    const takePhoto = () => {
        if (videoRef.current && canvasRef.current) {
            const video = videoRef.current;
            const canvas = canvasRef.current;
            canvas.width = video.videoWidth;
            canvas.height = video.videoHeight;
            canvas.getContext('2d').drawImage(video, 0, 0, canvas.width, canvas.height);
            onCapturePhoto(canvas.toDataURL('image/jpeg', 0.95));
        }
    };

    const startRecording = () => {
        if (!stream) return;
        chunksRef.current = [];
        const recorder = new MediaRecorder(stream);
        recorder.ondataavailable = e => { if (e.data.size > 0) chunksRef.current.push(e.data); };
        recorder.onstop = () => {
            // Тип берём у рекордера: Chrome пишет webm, Safari — mp4
            const blob = new Blob(chunksRef.current, { type: recorder.mimeType || 'video/webm' });
            onCaptureVideo(URL.createObjectURL(blob)); 
        };
        recorder.start();
        mediaRecorderRef.current = recorder;
        setIsRecording(true);
    };

    const stopRecording = () => {
        if (mediaRecorderRef.current) {
            mediaRecorderRef.current.stop();
            setIsRecording(false);
        }
    };

    return (
        <div className="cam-ov" dir={dir}>
            <style>{css}</style>
            {!isRecording && (
                <button type="button" className="cam-x" aria-label={t.close} title={t.close} onClick={onClose}>
                    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" aria-hidden="true"><path d="M6 6l12 12M18 6L6 18" /></svg>
                </button>
            )}
            {error ? <div className="cam-err">{error}</div> : (
                <div className="cam-fr">
                    <video ref={videoRef} autoPlay playsInline muted></video>
                    {isRecording && <div className="cam-rec">REC</div>}
                </div>
            )}
            <canvas ref={canvasRef} style={{ display: 'none' }}></canvas>

            {!error && (
                <div className="cam-bar">
                    {!isRecording && (
                        <button type="button" className="cam-b ph" aria-label={t.photo} title={t.photo} onClick={takePhoto}>
                            <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinejoin="round" aria-hidden="true"><path d="M4 8h3l2-3h6l2 3h3v11H4z" /><circle cx="12" cy="13" r="3.5" /></svg>
                        </button>
                    )}
                    {isRecording ? (
                        <button type="button" className="cam-b st" aria-label={t.stop} title={t.stop} onClick={stopRecording}><i /></button>
                    ) : (
                        <button type="button" className="cam-b vd" aria-label={t.video} title={t.video} onClick={startRecording}><i /></button>
                    )}
                </div>
            )}
        </div>
    );
}
```
