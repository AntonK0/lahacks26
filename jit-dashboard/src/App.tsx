import { useState } from 'react';
import './App.css';

const DEFAULT_JIT_MODELS = ['Idle.usdc', 'Wave.usdc', 'Yes.usdc', 'No.usdc'];

const NAV_ITEMS = [
  { label: 'Home', active: true },
  { label: 'Packages', active: false },
  { label: 'Textbooks', active: false },
  { label: 'Settings', active: false },
];

type ModelSource = 'default' | 'custom';

function formatFileSize(bytes: number) {
  if (!bytes) return '0 KB';

  const units = ['B', 'KB', 'MB', 'GB'];
  const exponent = Math.min(Math.floor(Math.log(bytes) / Math.log(1024)), units.length - 1);
  const value = bytes / 1024 ** exponent;

  return `${value.toFixed(value >= 10 || exponent === 0 ? 0 : 1)} ${units[exponent]}`;
}

function App() {
  const [isbn, setIsbn] = useState('');
  const [pdfFile, setPdfFile] = useState<File | null>(null);
  const [modelSource, setModelSource] = useState<ModelSource>('default');
  const [modelFiles, setModelFiles] = useState<File[]>([]);

  const modelRequirementMet = modelSource === 'default' || modelFiles.length > 0;
  const canPreparePackage = isbn.trim().length > 0 && Boolean(pdfFile) && modelRequirementMet;
  const completedSteps = Number(Boolean(isbn.trim())) + Number(Boolean(pdfFile)) + Number(modelRequirementMet);

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
                      Prepare Package
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
                      Draft
                    </span>
                  </div>

                  <div className="rounded-[1.3rem] bg-base-200/80 p-4 shadow-[0_18px_50px_rgba(15,23,42,0.08)] sm:p-5">
                    <form
                      id="package-form"
                      className="space-y-5"
                      onSubmit={(event) => event.preventDefault()}
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
                            <span className="label-text-alt">Used by the iPad scanner to route to this package.</span>
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
                      </div>

                      <div className="h-px bg-base-300" />

                      <div className="mb-3 flex items-center justify-between">
                        <h3 className="font-black">3D model source</h3>
                        <span className="text-xs font-bold text-base-content/55">USDC animation files</span>
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
                              onChange={() => setModelSource('default')}
                            />
                            <div>
                              <h4 className="font-black">Default JIT avatar</h4>
                              <p className="text-sm text-base-content/65">Use the bundled local animation set.</p>
                            </div>
                          </div>

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
                              onChange={() => setModelSource('custom')}
                            />
                            <div>
                              <h4 className="font-black">Custom animation set</h4>
                              <p className="text-sm text-base-content/65">Upload publisher-specific model animations.</p>
                            </div>
                          </div>

                          <input
                            type="file"
                            accept=".usdc"
                            multiple
                            className="file-input file-input-bordered file-input-primary w-full rounded-xl bg-base-100"
                            onChange={(event) => {
                              setModelSource('custom');
                              setModelFiles(Array.from(event.target.files ?? []));
                            }}
                          />
                        </label>
                      </div>

                      {modelSource === 'custom' && (
                        <div className="mt-4 rounded-[1.1rem] border border-dashed border-base-300 bg-base-100 p-4">
                          <div className="mb-3 flex items-center justify-between gap-3">
                            <h4 className="font-black">Selected model files</h4>
                            <span className="rounded-full bg-primary px-3 py-1 text-xs font-bold text-primary-content">
                              {modelFiles.length} file(s)
                            </span>
                          </div>

                          {modelFiles.length > 0 ? (
                            <ul className="grid gap-2 md:grid-cols-2">
                              {modelFiles.map((file) => (
                                <li key={`${file.name}-${file.lastModified}`} className="rounded-xl bg-base-200 p-3 text-sm">
                                  <div className="font-bold">{file.name}</div>
                                  <div className="text-base-content/60">{formatFileSize(file.size)}</div>
                                </li>
                              ))}
                            </ul>
                          ) : (
                            <p className="text-sm text-base-content/60">No custom `.usdc` files selected yet.</p>
                          )}
                        </div>
                      )}

                      <div className="mt-6 flex justify-end gap-2 border-t border-base-300 pt-5">
                        <button type="button" className="btn btn-ghost rounded-xl">Save draft</button>
                        <button type="submit" className="btn btn-primary rounded-xl" disabled={!canPreparePackage}>
                          Prepare package
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
