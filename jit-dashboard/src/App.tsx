import { type FormEvent, useState } from 'react';
import './App.css';

const DEFAULT_JIT_MODELS = ['Idle.usdc', 'Wave.usdc', 'Yes.usdc', 'No.usdc'];

const NAV_ITEMS = [
  { label: 'Home', active: true },
  { label: 'Packages', active: false },
  { label: 'Textbooks', active: false },
  { label: 'Settings', active: false },
];

type ModelSource = 'default' | 'custom';
type SubmitStatus = 'idle' | 'uploading-avatar' | 'submitting' | 'success' | 'error';

interface UploadResponse {
  collection: string;
  isbn: string;
  cloudinary_url: string;
  source_file: string;
  deleted_count: number;
  uploaded_count: number;
  embedding_model: string;
  embedding_dim: number;
}

interface UploadErrorResponse {
  detail?: string | Array<{ msg?: string }>;
  message?: string;
}

interface CloudinaryUploadResponse {
  secure_url?: string;
  error?: {
    message?: string;
  };
}

const uploadApiUrl = import.meta.env.VITE_UPLOAD_API_URL || 'https://lahacks26.onrender.com/upload-textbook';
const defaultJitCloudinaryUrl = import.meta.env.VITE_DEFAULT_JIT_CLOUDINARY_URL || '';
const cloudinaryCloudName = import.meta.env.VITE_CLOUDINARY_CLOUD_NAME || '';
const cloudinaryUploadPreset = import.meta.env.VITE_CLOUDINARY_UPLOAD_PRESET || '';

function formatError(result: UploadErrorResponse | null, fallback: string) {
  if (!result) return fallback;
  if (typeof result.detail === 'string') return result.detail;
  if (Array.isArray(result.detail) && result.detail[0]?.msg) return result.detail[0].msg;
  return result.message || fallback;
}

function isZipFile(file: File) {
  return file.name.toLowerCase().endsWith('.zip');
}

function formatFileSize(bytes: number) {
  if (!bytes) return '0 KB';

  const units = ['B', 'KB', 'MB', 'GB'];
  const exponent = Math.min(Math.floor(Math.log(bytes) / Math.log(1024)), units.length - 1);
  const value = bytes / 1024 ** exponent;

  return `${value.toFixed(value >= 10 || exponent === 0 ? 0 : 1)} ${units[exponent]}`;
}

function normalizeIsbn(value: string) {
  return value.replace(/\D/g, '');
}

async function uploadAvatarToCloudinary(file: File) {
  if (!cloudinaryCloudName || !cloudinaryUploadPreset) {
    throw new Error('Cloudinary cloud name and upload preset must be configured before uploading a custom avatar.');
  }

  if (!isZipFile(file)) {
    throw new Error('Custom avatars must be uploaded as one prebuilt .zip file containing the .usdc animation files.');
  }

  const uploadData = new FormData();
  uploadData.append('file', file);
  uploadData.append('upload_preset', cloudinaryUploadPreset);

  const response = await fetch(`https://api.cloudinary.com/v1_1/${cloudinaryCloudName}/raw/upload`, {
    method: 'POST',
    body: uploadData,
  });
  const result = (await response.json()) as CloudinaryUploadResponse;

  if (!response.ok || !result.secure_url) {
    throw new Error(result.error?.message || 'Cloudinary avatar upload failed.');
  }

  return result.secure_url;
}

function App() {
  const [isbn, setIsbn] = useState('');
  const [pdfFile, setPdfFile] = useState<File | null>(null);
  const [modelSource, setModelSource] = useState<ModelSource>('default');
  const [avatarFile, setAvatarFile] = useState<File | null>(null);
  const [cloudinaryUrl, setCloudinaryUrl] = useState(defaultJitCloudinaryUrl);
  const [submitStatus, setSubmitStatus] = useState<SubmitStatus>('idle');
  const [submitError, setSubmitError] = useState('');
  const [uploadResponse, setUploadResponse] = useState<UploadResponse | null>(null);
  const avatarZipInstructions = 'Create one .zip containing the avatar animation .usdc files, for example Idle.usdc, Wave.usdc, Yes.usdc, and No.usdc. Upload that zip here.';

  const normalizedIsbn = normalizeIsbn(isbn);
  const modelRequirementMet = modelSource === 'default' ? Boolean(defaultJitCloudinaryUrl) : Boolean(avatarFile && isZipFile(avatarFile));
  const canPreparePackage = normalizedIsbn.length === 13 && Boolean(pdfFile) && modelRequirementMet && submitStatus !== 'uploading-avatar' && submitStatus !== 'submitting';
  const completedSteps = Number(normalizedIsbn.length === 13) + Number(Boolean(pdfFile)) + Number(modelRequirementMet);
  const isSubmitting = submitStatus === 'uploading-avatar' || submitStatus === 'submitting';

  async function resolveCloudinaryUrl() {
    if (modelSource === 'default') {
      if (!defaultJitCloudinaryUrl) {
        throw new Error('VITE_DEFAULT_JIT_CLOUDINARY_URL is not configured for the default JIT avatar.');
      }

      setCloudinaryUrl(defaultJitCloudinaryUrl);
      return defaultJitCloudinaryUrl;
    }

    if (!avatarFile) {
      throw new Error('Choose a custom JIT avatar file before preparing the package.');
    }

    setSubmitStatus('uploading-avatar');
    const secureUrl = await uploadAvatarToCloudinary(avatarFile);
    setCloudinaryUrl(secureUrl);
    return secureUrl;
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSubmitError('');
    setUploadResponse(null);

    if (normalizedIsbn.length !== 13) {
      setSubmitStatus('error');
      setSubmitError('ISBN must contain exactly 13 digits.');
      return;
    }

    if (!pdfFile) {
      setSubmitStatus('error');
      setSubmitError('Choose a textbook PDF before preparing the package.');
      return;
    }

    if (modelSource === 'custom' && avatarFile && !isZipFile(avatarFile)) {
      setSubmitStatus('error');
      setSubmitError('Custom avatars must be uploaded as one prebuilt .zip file.');
      return;
    }

    try {
      const resolvedCloudinaryUrl = await resolveCloudinaryUrl();
      const payload = new FormData();
      payload.append('isbn', normalizedIsbn);
      payload.append('cloudinary_url', resolvedCloudinaryUrl);
      payload.append('file', pdfFile);

      setSubmitStatus('submitting');
      const response = await fetch(uploadApiUrl, {
        method: 'POST',
        body: payload,
      });
      const result = (await response.json().catch(() => null)) as (UploadResponse & UploadErrorResponse) | null;

      if (!response.ok) {
        throw new Error(formatError(result, 'FastAPI upload failed.'));
      }

      setUploadResponse(result as UploadResponse);
      setSubmitStatus('success');
    } catch (error) {
      setSubmitStatus('error');
      setSubmitError(error instanceof Error ? error.message : 'Package upload failed.');
    }
  }

  return (
    <div className="min-h-screen bg-base-200 text-base-content" data-theme="jitPublisher">
      <main className="mx-auto grid min-h-screen max-w-[1120px] overflow-hidden bg-base-100 min-[900px]:grid-cols-[168px_minmax(0,1fr)]">
        <aside className="hidden border-r border-base-300 bg-base-100 px-4 py-7 min-[900px]:block">
          <nav className="space-y-1">
            {NAV_ITEMS.map((item) => (
              <button
                key={item.label}
                type="button"
                className={`flex w-full items-center gap-2 rounded-md px-3 py-2 text-left text-sm font-semibold transition ${
                  item.active ? 'bg-base-300/80 text-base-content' : 'text-base-content/70 hover:bg-base-300/50 hover:text-base-content'
                }`}
              >
                <span className={`h-3 w-3 rounded-sm border ${item.active ? 'border-primary bg-primary/15' : 'border-base-content/40'}`} />
                {item.label}
              </button>
            ))}
          </nav>
        </aside>

        <section className="mx-auto w-full max-w-[900px] space-y-5 px-5 py-5 sm:px-8 sm:py-7">
                <div>
                  <h1 className="text-3xl font-black tracking-tight sm:text-4xl">Home</h1>
                  <p className="mt-1 text-sm font-semibold text-base-content/55">Create and prepare textbook packages for the JIT iPad app.</p>
                </div>

                <div className="rounded-[1.35rem] bg-primary p-6 text-primary-content shadow-[0_24px_70px_rgba(0,149,255,0.22)] sm:p-7">
                  <div className="max-w-2xl">
                    <p className="mb-2 text-sm font-bold uppercase tracking-[0.18em] opacity-80">Publisher console</p>
                    <h2 className="text-4xl font-black leading-none tracking-tight sm:text-5xl">Build a Jit package</h2>
                    <p className="mt-3 max-w-xl text-base leading-tight text-primary-content/85 sm:text-lg">
                      Upload the textbook, choose the animation set, and prepare the package the iPad app loads after scanning the ISBN.
                    </p>
                  </div>

                  <div className="mt-6 flex flex-wrap items-center gap-3">
                    <button type="submit" form="package-form" className="btn border-0 bg-white text-primary hover:bg-white/90" disabled={!canPreparePackage}>
                      {isSubmitting ? 'Preparing...' : 'Prepare Package'}
                    </button>
                    <span className="rounded-full bg-white/15 px-4 py-2 text-sm font-semibold">
                      {completedSteps}/3 steps ready
                    </span>
                  </div>
                </div>

                <div>
                  <div className="mb-3 flex items-end justify-between gap-4">
                    <div>
                      <h2 className="text-xl font-black tracking-tight">Package Builder</h2>
                      <p className="text-sm text-base-content/55">Required fields only. Clean, quick, and ready for backend hooks.</p>
                    </div>
                    <span className="hidden rounded-full bg-base-200 px-3 py-1 text-xs font-bold text-base-content/60 sm:inline-flex">
                      {submitStatus === 'success' ? 'Saved' : 'Draft'}
                    </span>
                  </div>

                  <div className="rounded-[1.3rem] bg-base-200/80 p-4 shadow-[0_18px_50px_rgba(15,23,42,0.08)] sm:p-5">
                    <form
                      id="package-form"
                      className="space-y-5"
                      onSubmit={handleSubmit}
                    >
                      <div className="grid gap-4 sm:grid-cols-2">
                        <label className="form-control w-full">
                          <div className="label">
                            <span className="label-text text-sm font-black">Textbook ISBN</span>
                            <span className="label-text-alt text-error">*</span>
                          </div>
                          <input
                            type="text"
                            inputMode="numeric"
                            placeholder="978-0-13-409341-3"
                            className="input input-bordered h-12 w-full rounded-xl bg-base-100 text-base"
                            value={isbn}
                            onChange={(event) => setIsbn(event.target.value)}
                          />
                          <div className="label">
                            <span className={`label-text-alt ${isbn && normalizedIsbn.length !== 13 ? 'text-error' : ''}`}>
                              {isbn && normalizedIsbn.length !== 13 ? 'ISBN must resolve to 13 digits.' : 'Used by the iPad scanner to route to this package.'}
                            </span>
                          </div>
                        </label>

                        <label className="form-control w-full">
                          <div className="label">
                            <span className="label-text text-sm font-black">PDF Upload</span>
                            <span className="label-text-alt text-error">*</span>
                          </div>
                          <input
                            type="file"
                            accept="application/pdf"
                            className="file-input file-input-bordered h-12 w-full rounded-xl bg-base-100"
                            onChange={(event) => setPdfFile(event.target.files?.[0] ?? null)}
                          />
                          <div className="label">
                            <span className="label-text-alt">Source material for chunking and retrieval.</span>
                          </div>
                        </label>

                        <div className="rounded-xl bg-base-100 p-4 text-sm text-base-content/65 sm:col-span-2">
                          The backend receives only the ISBN, the textbook PDF, and the Cloudinary URL for the avatar package.
                        </div>
                      </div>

                      <div className="h-px bg-base-300" />

                      <div className="mb-3 flex items-center justify-between">
                        <h3 className="font-black">3D model source</h3>
                        <span className="text-xs font-bold text-base-content/55">Cloudinary secure URL</span>
                      </div>

                      <div className="grid gap-3 sm:grid-cols-2">
                        <label
                          className={`cursor-pointer rounded-[1.1rem] border p-4 transition ${
                            modelSource === 'default' ? 'border-primary bg-primary/10' : 'border-base-300 bg-base-100 hover:border-primary/60'
                          }`}
                        >
                          <div className="mb-4 flex items-start gap-3">
                            <input
                              type="radio"
                              name="model-source"
                              className="radio radio-primary mt-1"
                              checked={modelSource === 'default'}
                              onChange={() => {
                                setModelSource('default');
                                setCloudinaryUrl(defaultJitCloudinaryUrl);
                              }}
                            />
                            <div>
                              <h4 className="font-black">Default JIT avatar</h4>
                              <p className="text-sm text-base-content/65">
                                Use the pre-existing Cloudinary URL from `VITE_DEFAULT_JIT_CLOUDINARY_URL`.
                              </p>
                            </div>
                          </div>

                          <div className="space-y-3">
                            <div className="grid grid-cols-2 gap-2">
                              {DEFAULT_JIT_MODELS.map((model, index) => (
                                <span
                                  key={model}
                                  className={`rounded-xl px-3 py-2 text-xs font-black ${
                                    index % 2 === 0 ? 'bg-[#ffd30d] text-[#075694]' : 'bg-[#01a0f4] text-white'
                                  }`}
                                >
                                  {model}
                                </span>
                              ))}
                            </div>
                            <p className={`truncate text-xs font-semibold ${defaultJitCloudinaryUrl ? 'text-base-content/55' : 'text-error'}`}>
                              {defaultJitCloudinaryUrl ? 'Default Cloudinary URL configured.' : 'Missing VITE_DEFAULT_JIT_CLOUDINARY_URL.'}
                            </p>
                          </div>
                        </label>

                        <label
                          className={`cursor-pointer rounded-[1.1rem] border p-4 transition ${
                            modelSource === 'custom' ? 'border-primary bg-primary/10' : 'border-base-300 bg-base-100 hover:border-primary/60'
                          }`}
                        >
                          <div className="mb-4 flex items-start gap-3">
                            <input
                              type="radio"
                              name="model-source"
                              className="radio radio-primary mt-1"
                              checked={modelSource === 'custom'}
                              onChange={() => {
                                setModelSource('custom');
                                setCloudinaryUrl('');
                              }}
                            />
                            <div>
                              <h4 className="font-black">Custom JIT avatar</h4>
                              <p className="text-sm text-base-content/65">Upload one prebuilt avatar zip to Cloudinary, then send its secure URL.</p>
                            </div>
                          </div>

                          <div className="mb-3 rounded-xl bg-base-200 p-3 text-xs font-semibold text-base-content/65" title={avatarZipInstructions}>
                            Need the zip format? Include each animation as a `.usdc` file at the zip root, such as Idle, Wave, Yes, and No.
                          </div>

                          <input
                            type="file"
                            accept=".zip,application/zip,application/x-zip-compressed"
                            title={avatarZipInstructions}
                            className="file-input file-input-bordered file-input-primary w-full rounded-xl bg-base-100"
                            onChange={(event) => {
                              setModelSource('custom');
                              setAvatarFile(event.target.files?.[0] ?? null);
                              setCloudinaryUrl('');
                            }}
                          />
                        </label>
                      </div>

                      {modelSource === 'custom' && (
                        <div className="mt-4 rounded-[1.1rem] border border-dashed border-base-300 bg-base-100 p-4">
                          <div className="mb-3 flex items-center justify-between gap-3">
                            <h4 className="font-black">Selected avatar zip</h4>
                            <span className="rounded-full bg-primary px-3 py-1 text-xs font-bold text-primary-content">
                              {avatarFile ? '1 file' : '0 files'}
                            </span>
                          </div>

                          {avatarFile ? (
                            <div className="rounded-xl bg-base-200 p-3 text-sm">
                              <div className="font-bold">{avatarFile.name}</div>
                              <div className={isZipFile(avatarFile) ? 'text-base-content/60' : 'text-error'}>
                                {isZipFile(avatarFile)
                                  ? formatFileSize(avatarFile.size)
                                  : 'Choose a .zip file containing the .usdc animation files.'}
                              </div>
                            </div>
                          ) : (
                            <p className="text-sm text-base-content/60">No custom JIT avatar zip selected yet.</p>
                          )}
                        </div>
                      )}

                      {cloudinaryUrl && (
                        <div className="rounded-xl bg-base-100 p-3 text-sm">
                          <p className="font-bold text-base-content/60">Resolved Cloudinary URL</p>
                          <p className="truncate text-base-content/80">{cloudinaryUrl}</p>
                        </div>
                      )}

                      {submitStatus === 'success' && uploadResponse && (
                        <div className="rounded-xl border border-success/20 bg-success/10 p-3 text-sm text-success-content">
                          <p className="font-bold">Textbook package uploaded successfully.</p>
                          <p className="mt-1">
                            ISBN {uploadResponse.isbn} saved {uploadResponse.uploaded_count} chunks from {uploadResponse.source_file}.
                          </p>
                        </div>
                      )}

                      {submitStatus === 'error' && submitError && (
                        <div className="rounded-xl border border-error/20 bg-error/10 p-3 text-sm text-error">
                          {submitError}
                        </div>
                      )}

                      <div className="mt-6 flex justify-end gap-2 border-t border-base-300 pt-5">
                        <button type="button" className="btn btn-ghost rounded-xl" disabled={isSubmitting}>Save draft</button>
                        <button type="submit" className="btn btn-primary rounded-xl" disabled={!canPreparePackage}>
                          {submitStatus === 'uploading-avatar' && 'Uploading avatar zip...'}
                          {submitStatus === 'submitting' && 'Sending to FastAPI...'}
                          {!isSubmitting && 'Prepare package'}
                        </button>
                      </div>
                    </form>
                  </div>
                </div>
        </section>
      </main>
    </div>
  );
}

export default App;
