import { useState } from 'react';
import './App.css';

const DEFAULT_JIT_MODELS = ['Idle.usdc', 'Wave.usdc', 'Yes.usdc', 'No.usdc'];

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

  return (
    <div className="min-h-screen bg-base-200 text-base-content" data-theme="jitPublisher">
      <div className="drawer lg:drawer-open">
        <input id="publisher-drawer" type="checkbox" className="drawer-toggle" />

        <div className="drawer-content flex min-h-screen flex-col">
          <header className="navbar border-b border-base-300 bg-base-100 px-4 lg:px-8">
            <div className="flex-none lg:hidden">
              <label htmlFor="publisher-drawer" className="btn btn-square btn-ghost" aria-label="Open navigation">
                <span className="text-xl">=</span>
              </label>
            </div>

            <div className="flex-1">
              <div>
                <p className="text-sm font-medium text-base-content/60">Publisher Console</p>
                <h1 className="text-xl font-bold tracking-tight">JIT textbook package builder</h1>
              </div>
            </div>

            <div className="hidden items-center gap-3 md:flex">
              <div className="text-right">
                <p className="text-sm font-semibold">Acme Learning Press</p>
                <p className="text-xs text-base-content/60">Draft workspace</p>
              </div>
              <div className="avatar placeholder">
                <div className="w-10 rounded-full bg-primary text-primary-content">
                  <span>AP</span>
                </div>
              </div>
            </div>
          </header>

          <main className="flex-1 p-4 lg:p-8">
            <div className="mx-auto flex max-w-6xl flex-col gap-6">
              <section className="rounded-box border border-base-300 bg-base-100 p-5 shadow-sm">
                <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
                  <div>
                    <div className="badge badge-primary badge-outline mb-3">Edge AR tutor setup</div>
                    <h2 className="text-3xl font-bold tracking-tight">Create a textbook package</h2>
                    <p className="mt-2 max-w-2xl text-base-content/70">
                      Upload textbook content and choose the animation model set the iPad app should load after scanning
                      the book ISBN.
                    </p>
                  </div>

                  <ul className="steps steps-vertical lg:steps-horizontal">
                    <li className="step step-primary">ISBN</li>
                    <li className={`step ${pdfFile ? 'step-primary' : ''}`}>PDF</li>
                    <li className={`step ${modelRequirementMet ? 'step-primary' : ''}`}>Models</li>
                  </ul>
                </div>
              </section>

              <div className="grid gap-6 xl:grid-cols-[1fr_360px]">
                <form className="card border border-base-300 bg-base-100 shadow-sm" onSubmit={(event) => event.preventDefault()}>
                  <div className="card-body gap-6">
                    <div className="flex flex-col gap-2 sm:flex-row sm:items-start sm:justify-between">
                      <div>
                        <h3 className="card-title text-2xl">Required submission fields</h3>
                        <p className="text-sm text-base-content/60">
                          This is UI-only for now. API upload and processing hooks can be connected later.
                        </p>
                      </div>
                      <div className="badge badge-neutral">Draft</div>
                    </div>

                    <div className="grid gap-5 md:grid-cols-2">
                      <label className="form-control md:col-span-2">
                        <div className="label">
                          <span className="label-text font-semibold">Textbook ISBN</span>
                          <span className="label-text-alt text-error">*</span>
                        </div>
                        <input
                          type="text"
                          inputMode="numeric"
                          placeholder="978-0-13-409341-3"
                          className="input input-bordered w-full"
                          value={isbn}
                          onChange={(event) => setIsbn(event.target.value)}
                        />
                        <div className="label">
                          <span className="label-text-alt">
                            Used by the iPad barcode scanner to route to this package.
                          </span>
                        </div>
                      </label>

                      <label className="form-control md:col-span-2">
                        <div className="label">
                          <span className="label-text font-semibold">PDF Upload</span>
                          <span className="label-text-alt text-error">*</span>
                        </div>
                        <input
                          type="file"
                          accept="application/pdf"
                          className="file-input file-input-bordered w-full"
                          onChange={(event) => setPdfFile(event.target.files?.[0] ?? null)}
                        />
                        <div className="label">
                          <span className="label-text-alt">
                            The selected PDF will become the source material for chunking and retrieval.
                          </span>
                        </div>
                      </label>
                    </div>

                    <div className="divider my-0">3D model source</div>

                    <div className="grid gap-4 lg:grid-cols-2">
                      <label className="card cursor-pointer border border-base-300 bg-base-200 transition hover:border-primary">
                        <div className="card-body gap-3">
                          <div className="flex items-start gap-3">
                            <input
                              type="radio"
                              name="model-source"
                              className="radio radio-primary mt-1"
                              checked={modelSource === 'default'}
                              onChange={() => setModelSource('default')}
                            />
                            <div>
                              <h4 className="font-semibold">Use default JIT avatar</h4>
                              <p className="text-sm text-base-content/70">
                                Start with the bundled animation files from the local JIT folder.
                              </p>
                            </div>
                          </div>

                          <div className="flex flex-wrap gap-2">
                            {DEFAULT_JIT_MODELS.map((model) => (
                              <span key={model} className="badge badge-outline">
                                {model}
                              </span>
                            ))}
                          </div>
                        </div>
                      </label>

                      <label className="card cursor-pointer border border-base-300 bg-base-200 transition hover:border-primary">
                        <div className="card-body gap-3">
                          <div className="flex items-start gap-3">
                            <input
                              type="radio"
                              name="model-source"
                              className="radio radio-primary mt-1"
                              checked={modelSource === 'custom'}
                              onChange={() => setModelSource('custom')}
                            />
                            <div>
                              <h4 className="font-semibold">Upload custom animation set</h4>
                              <p className="text-sm text-base-content/70">
                                Choose multiple `.usdc` files when a publisher provides custom model animations.
                              </p>
                            </div>
                          </div>

                          <input
                            type="file"
                            accept=".usdc"
                            multiple
                            className="file-input file-input-bordered file-input-primary w-full"
                            onChange={(event) => {
                              setModelSource('custom');
                              setModelFiles(Array.from(event.target.files ?? []));
                            }}
                          />
                        </div>
                      </label>
                    </div>

                    {modelSource === 'custom' && (
                      <div className="rounded-box border border-dashed border-base-300 bg-base-200 p-4">
                        <div className="mb-3 flex items-center justify-between gap-3">
                          <h4 className="font-semibold">Selected model files</h4>
                          <span className="badge badge-primary">{modelFiles.length} file(s)</span>
                        </div>

                        {modelFiles.length > 0 ? (
                          <ul className="grid gap-2 md:grid-cols-2">
                            {modelFiles.map((file) => (
                              <li key={`${file.name}-${file.lastModified}`} className="rounded-box bg-base-100 p-3 text-sm">
                                <div className="font-medium">{file.name}</div>
                                <div className="text-base-content/60">{formatFileSize(file.size)}</div>
                              </li>
                            ))}
                          </ul>
                        ) : (
                          <p className="text-sm text-base-content/60">
                            No custom `.usdc` files selected yet.
                          </p>
                        )}
                      </div>
                    )}

                    {/* <label className="form-control">
                      <div className="label">
                        <span className="label-text font-semibold">Publisher notes</span>
                        <span className="label-text-alt">Optional</span>
                      </div>
                      <textarea
                        className="textarea textarea-bordered min-h-28"
                        placeholder="Add chapter ranges, edition notes, or animation mapping details for the ingestion team."
                      />
                    </label> */}

                    <div className="card-actions justify-end border-t border-base-300 pt-6">
                      <button type="button" className="btn btn-ghost">Save draft</button>
                      <button type="submit" className="btn btn-primary" disabled={!canPreparePackage}>
                        Prepare package
                      </button>
                    </div>
                  </div>
                </form>

                <aside className="flex flex-col gap-6">
                  <div className="card border border-base-300 bg-base-100 shadow-sm">
                    <div className="card-body">
                      <h3 className="card-title">Package summary</h3>

                      <div className="stats stats-vertical bg-base-200">
                        <div className="stat">
                          <div className="stat-title">ISBN</div>
                          <div className="stat-value text-lg">{isbn || 'Not set'}</div>
                        </div>
                        <div className="stat">
                          <div className="stat-title">PDF</div>
                          <div className="stat-value text-lg">{pdfFile ? 'Selected' : 'Missing'}</div>
                          {pdfFile && <div className="stat-desc">{pdfFile.name}</div>}
                        </div>
                        <div className="stat">
                          <div className="stat-title">Model set</div>
                          <div className="stat-value text-lg">
                            {modelSource === 'default' ? 'Default JIT' : `${modelFiles.length} custom`}
                          </div>
                          <div className="stat-desc">
                            {modelSource === 'default' ? '4 bundled animations' : 'USDC animation files'}
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>

                  <div className="alert border border-info/30 bg-info/10 text-info-content">
                    <div>
                      <h4 className="font-semibold">Next integration step</h4>
                      <p className="text-sm">
                        Later, this form can send PDFs to ingestion and model files to Cloudinary or another asset store.
                      </p>
                    </div>
                  </div>

                  <div className="card border border-base-300 bg-base-100 shadow-sm">
                    <div className="card-body">
                      <h3 className="card-title">Recent packages</h3>
                      <div className="overflow-x-auto">
                        <table className="table table-sm">
                          <thead>
                            <tr>
                              <th>Book</th>
                              <th>Status</th>
                            </tr>
                          </thead>
                          <tbody>
                            <tr>
                              <td>Biology 101</td>
                              <td><span className="badge badge-success badge-sm">Ready</span></td>
                            </tr>
                            <tr>
                              <td>Physics Lab</td>
                              <td><span className="badge badge-warning badge-sm">Draft</span></td>
                            </tr>
                          </tbody>
                        </table>
                      </div>
                    </div>
                  </div>
                </aside>
              </div>
            </div>
          </main>
        </div>

        <div className="drawer-side z-20">
          <label htmlFor="publisher-drawer" aria-label="Close navigation" className="drawer-overlay" />
          <aside className="min-h-full w-64 border-r border-base-300 bg-base-100">
            <div className="border-b border-base-300 p-5">
              <div className="flex items-center gap-3">
                <div className="flex h-10 w-10 items-center justify-center rounded-box bg-primary font-bold text-primary-content">
                  J
                </div>
                <div>
                  <p className="font-bold">JIT Dashboard</p>
                  <p className="text-xs text-base-content/60">Publisher tools</p>
                </div>
              </div>
            </div>

            <ul className="menu gap-1 p-4">
              <li>
                <a className="active">Dashboard</a>
              </li>
              <li>
                <a>Textbooks</a>
              </li>
              <li>
                <a>Settings</a>
              </li>
            </ul>
          </aside>
        </div>
      </div>
    </div>
  );
}

export default App;
