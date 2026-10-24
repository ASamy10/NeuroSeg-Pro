<div align="center">

# 🧠 NeuroSeg Pro
### Advancing Generalizability in 3D Volumetric Brain Tumor Segmentation Across Diverse Populations

[![Version](https://img.shields.io/badge/Version-v4.0.0-blue.svg?style=for-the-badge&logo=github)](https://github.com/ASamy10/NeuroSeg-Pro/releases)
[![OS Windows](https://img.shields.io/badge/OS-Windows_10%20%7C%2011-0078D6.svg?style=for-the-badge&logo=windows&logoColor=white)](#-system-requirements)
[![Python](https://img.shields.io/badge/Python-3.11-3776AB.svg?style=for-the-badge&logo=python&logoColor=white)](#-system-requirements)
[![PyTorch](https://img.shields.io/badge/PyTorch-2.5%2Bcu121-EE4C2C.svg?style=for-the-badge&logo=pytorch&logoColor=white)](#-gpu--cuda-acceleration)
[![MONAI](https://img.shields.io/badge/MONAI-1.3%2B-1E88E5.svg?style=for-the-badge)](https://monai.io/)
[![PennyLane Quantum](https://img.shields.io/badge/PennyLane-Quantum_AI-430098.svg?style=for-the-badge)](https://pennylane.ai/)
[![License](https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge)](LICENSE)

---

**NeuroSeg Pro** is an enterprise-grade clinical desktop platform and deep learning research framework designed for automated, generalizable 3D multi-modal MRI brain tumor segmentation. By integrating **Hybrid Quantum-Classical Feature Extraction (Parallel Quantum Bottleneck DynUNet)**, **Multi-Teacher Cross-Population Knowledge Distillation**, and **Demographic Stratified Batch Sampling**, NeuroSeg Pro delivers sub-voxel segmentation accuracy and unprecedented cross-cohort generalizability.

[📥 Download Windows Installer](https://github.com/ASamy10/NeuroSeg-Pro/releases) • [📓 Research Notebook](research/notebooks/training-testing-any-hybrid-teacher-newlabels.ipynb) • [📊 Project Presentation (PDF)](docs/NeuroSeg_Pro_Graduation_Project_Presentation.pdf) • [🔬 Research Docs](research/README.md)

<br/>

<img src="assets/screenshots/clinical_platform_triplanar_metrics.png" alt="NeuroSeg Pro Triplanar Clinical Viewer" width="98%" style="border-radius: 8px; box-shadow: 0 8px 24px rgba(0,0,0,0.18);"/>
<p><em>NeuroSeg Pro v4.0.0: Interactive triplanar (Axial, Sagittal, Coronal) viewer with synchronized ground-truth comparison, real-time volumetric quantification (WT, TC, ET cm³), and instant sub-second clinical inference.</em></p>

</div>

---

## 📑 Table of Contents
- [🌟 Executive Summary & Clinical Urgency](#-executive-summary--clinical-urgency)
- [🖥️ Clinical Desktop Platform Highlights](#️-clinical-desktop-platform-highlights)
- [👥 Diverse Target Populations & Dataset Diversity](#-diverse-target-populations--dataset-diversity)
- [⚖️ Stratified Batch Sampling (Fairness Strategy)](#️-stratified-batch-sampling-fairness-strategy)
- [⚛️ Hybrid Quantum-Classical DynUNet Architecture](#️-hybrid-quantum-classical-dynunet-architecture)
- [🎓 Multi-Teacher Knowledge Distillation (KD)](#-multi-teacher-knowledge-distillation-kd)
- [📊 Benchmark Results & Quantitative Evaluation](#-benchmark-results--quantitative-evaluation)
- [📓 Research & Training Notebook](#-research--training-notebook)
- [🎯 Clinical Segmentation Workflow](#-clinical-segmentation-workflow)
- [🖥️ System Requirements](#️-system-requirements)
- [🚀 Installation & Quick Start](#-installation--quick-start)
- [🏗️ Software Architecture](#️-software-architecture)
- [👥 Authors, Supervisors & Academic Mentorship](#-authors-supervisors--academic-mentorship)
- [⚖️ License](#️-license)

---

## 🌟 Executive Summary & Clinical Urgency

<p align="center">
  <img src="assets/diagrams/clinical_urgency.png" alt="Clinical Urgency" width="85%"/>
</p>

Brain tumors are the **5th most common cancer** and the **10th leading cause of death** worldwide, carrying a devastating **5-year survival rate of only 12%**. Manual MRI delineation by expert neuroradiologists takes **3 to 5 hours per case**, creating a critical diagnostic bottleneck in oncology workflows.

While deep learning provides a rapid alternative, existing models suffer from three fundamental limitations:
1. **Domain Generalizability Gap**: Discrepancies in scanner field strength (1.5T vs. 3.0T), imaging protocols, and patient demographics cause conventional models to fail when deployed across different hospitals.
2. **Demographic Imbalance**: Datasets are overwhelmingly dominated by standard high-income adult glioma cohorts, leading to high error rates on underrepresented populations such as pediatric and Sub-Saharan African patients.
3. **High Computational Overhead**: 3D Vision Transformers require prohibitive GPU memory, preventing real-time deployment in resource-constrained medical centers.

**NeuroSeg Pro** addresses these challenges head-on with a mathematically rigorous, clinically validated solution.

---

## 🖥️ Clinical Desktop Platform Highlights

<p align="center">
  <img src="assets/screenshots/clinical_platform_sequence_verification.png" alt="Sequence Verification & Segmentation" width="95%"/>
</p>

* **⚡ Ultra-Fast Volumetric Inference**: Optimized PyTorch / MONAI sliding-window inference engine executing 3D volumetric segmentation in **~142 ms** on standard workstations.
* **🩺 Multi-Modal NIfTI Loader**: Native parsing and automated alignment for all four standard MRI contrasts (`T1`, `T1ce`, `T2`, `FLAIR`).
* **📐 Triplanar Synchronized Navigation**: Dual cross-viewport synchronization between AI model predictions and ground-truth annotations across Axial, Sagittal, and Coronal planes.
* **📊 Volumetric Clinical Metrics**: Automated volume estimation ($\text{cm}^3$) for Whole Tumor (WT), Tumor Core (TC), and Enhancing Tumor (ET), paired with DSC and HD95 telemetry.
* **🔕 Silent Windows Deployment**: Complete zero-touch MSI/EXE installer with self-healing virtual environment bootstrapping (`%LOCALAPPDATA%\NeuroSegPro\.venv`).

---

## 👥 Diverse Target Populations & Dataset Diversity

Our study evaluates model generalizability across **5 distinct tumor populations** ($N = 2,824$ multi-modal 3D MRI scans):

<p align="center">
  <img src="assets/diagrams/cohort_anatomical_diversity.png" alt="Morphological Diversity Across Populations" width="95%"/>
</p>

| Cohort | Clinical Description | Samples ($N$) | Diagnostic & Anatomical Challenge |
| :--- | :--- | :---: | :--- |
| **GLI** | Adult Glioma (BraTS) | **1,251** | Infiltrative margins, heterogeneous necrotic cores |
| **MEN** | Intracranial Meningioma | **1,000** | Dural-based extra-axial masses, displacement of brain tissue |
| **MET** | Brain Metastases | **328** | Multifocal, well-circumscribed lesions with extensive peritumoral edema |
| **SSA** | Sub-Saharan African Glioma | **146** | High protocol variability, varied scanner SNR |
| **PED** | Pediatric Brain Tumors | **99** | Predilection for posterior fossa, distinctive histology |

<p align="center">
  <img src="assets/diagrams/tumor_subregions_and_populations.png" alt="Tumor Sub-Regions" width="85%"/>
</p>

---

## ⚖️ Stratified Batch Sampling (Fairness Strategy)

To resolve severe population imbalances (e.g., 1,251 Adult Glioma vs. 99 Pediatric cases), we designed a **Stratified Demographic Batch Sampler**:

<p align="center">
  <img src="assets/diagrams/stratified_batch_sampling.png" alt="Stratified Batch Sampling" width="60%"/>
</p>

Each training mini-batch samples exactly one patient from each population: $[\text{GLI}, \text{SSA}, \text{PED}, \text{MEN}, \text{MET}]$. Underrepresented cohorts cycle with replacement, guaranteeing that the model learns unbiased representations across all populations simultaneously.

---

## ⚛️ Hybrid Quantum-Classical DynUNet Architecture

NeuroSeg Pro replaces the deepest spatial bottleneck of a 3D DynUNet with a **Parallel Quantum Bottleneck** utilizing [PennyLane](https://pennylane.ai/):

<p align="center">
  <img src="assets/diagrams/quantum_dynunet_architecture.png" alt="Quantum DynUNet Architecture" width="95%"/>
</p>

### Technical Highlights:
* **Deep Feature Projection**: At the bottleneck ($384 \times 4 \times 4 \times 4$), adaptive 3D average pooling compresses spatial representations into $384 \times 1 \times 1 \times 1$.
* **Parallel Variational Circuits**: Two parallel 10-qubit Quantum Processing Layers (`AngleEmbedding` + `StronglyEntanglingLayers`) evaluate expectation values $\langle Z_i \rangle$.
* **Parameter Reduction**: Slashes model parameters from **137.66M to 66.92M (-51.39% parameter reduction)** while boosting validation accuracy:

| Metric (Task03 Proof of Concept) | Classical Model | Hybrid Quantum Model | Improvement |
| :--- | :---: | :---: | :---: |
| **Training Dice** | 0.9262 | **0.9332** | **+0.76%** |
| **Validation Dice** | 0.9229 | **0.9360** | **+1.42%** |
| **Total Parameters** | 137,662,753 | **66,922,971** | **-51.39%** |

---

## 🎓 Multi-Teacher Knowledge Distillation (KD)

Rather than running five separate massive models in clinical practice, we distill five specialized teacher networks into a single, compact **Generalized Student Model**:

<p align="center">
  <img src="assets/diagrams/multi_cohort_kd_pipeline.jpg" alt="Multi-Teacher KD Pipeline" width="85%"/>
</p>

### Compound Distillation Objective:
The student model is guided by a triple-term loss:

$$\mathcal{L}_{\text{total}} = \mathcal{L}_{\text{seg}}^{\text{DS}} + \alpha \, \mathcal{L}_{\text{logits}}^{\text{DS}} + \beta \, \mathcal{L}_{\text{KL}}$$

<p align="center">
  <img src="assets/diagrams/knowledge_distillation_detailed_loss.png" alt="Knowledge Distillation Loss Formulation" width="92%"/>
</p>

1. **Deep Supervision Segmentation Loss ($\mathcal{L}_{\text{seg}}^{\text{DS}}$)**: Combines Dice Loss + BCE across the last three decoder levels against reference segmentations.
2. **Logits Distillation ($\mathcal{L}_{\text{logits}}^{\text{DS}}$)**: Uses temperature scaling ($T$) and sigmoid thresholding to transfer probability distributions from teacher decoders to student decoders.
3. **CBAM Intermediate Feature Matching ($\mathcal{L}_{\text{KL}}$)**: Channel and Spatial Attention (CBAM) blocks extract refined spatial attention maps, aligning student and teacher bottleneck features via Kullback-Leibler divergence.

---

## 📊 Benchmark Results & Quantitative Evaluation

### 1. Teacher Models: Hybrid Quantum vs. Classical

<p align="center">
  <img src="assets/diagrams/teacher_models_comparison.png" alt="Teacher Models Comparison" width="85%"/>
</p>

| Cohort | Metric | Hybrid Teacher (Proposed) | Classical Teacher | Difference (%) |
| :--- | :--- | :---: | :---: | :---: |
| **Glioma (GLI)** | Average Dice<br/>Average HD95 | **0.8864**<br/>**6.59 mm** | 0.8823<br/>6.20 mm | **+0.46%**<br/>+6.22% |
| **Sub-Saharan Africa (SSA)** | Average Dice<br/>Average HD95 | 0.7906<br/>14.42 mm | **0.8013**<br/>**13.51 mm** | -1.34%<br/>+6.78% |
| **Pediatric (PED)** | Average Dice<br/>Average HD95 | **0.7162**<br/>**20.26 mm** | 0.6587<br/>35.52 mm | **+8.73%**<br/>**-42.96% (better)** |
| **Meningioma (MEN)** | Average Dice<br/>Average HD95 | **0.8262**<br/>**24.89 mm** | 0.8247<br/>35.34 mm | **+0.18%**<br/>**-29.58% (better)** |
| **Metastases (MET)** | Average Dice<br/>Average HD95 | **0.6037**<br/>**27.56 mm** | 0.5627<br/>47.87 mm | **+7.29%**<br/>**-42.43% (better)** |

### 2. Multi-Method Benchmark Against SOTA

<p align="center">
  <img src="assets/diagrams/qualitative_benchmark_comparison.png" alt="Qualitative Segmentation Benchmark" width="95%"/>
  <br/>
  <em>Visual comparison against Vanilla, Fine-tuned, Continual Learning (CL, RCL), and Ensemble baselines (Hard Voting, Weighted Voting, Uncertainty-Guided Fusion).</em>
</p>

The proposed student model demonstrates remarkable boundary sharpness, maintaining top DSC scores across Adult Glioma (0.946), Sub-Saharan Africa (0.948), Pediatric (0.929), Meningioma (0.894), and Metastases (0.761).

---

## 📓 Research & Training Notebook

The complete PyTorch training, validation, ClearML logging, and evaluation pipeline is open-sourced in:
👉 [`research/notebooks/training-testing-any-hybrid-teacher-newlabels.ipynb`](research/notebooks/training-testing-any-hybrid-teacher-newlabels.ipynb)

For an in-depth mathematical walkthrough and reproduction guide, see the [Research Documentation](research/README.md).

---

## 🎯 Clinical Segmentation Workflow

NeuroSeg Pro processes four multi-parametric MRI sequences (`T1`, `T1ce`, `T2`, `FLAIR`) in NIfTI format (`.nii` / `.nii.gz`):

```mermaid
graph LR
    A["T1 scan"] --> E["Multi-Modal 4D Stack"]
    B["T1ce scan"] --> E
    C["T2 scan"] --> E
    D["FLAIR scan"] --> E
    E --> F["MONAI DynUNet Engine"]
    F --> G["Sliding-Window Inference (128x128x128 / overlap=0.5)"]
    G --> H["Hierarchical Sigmoid Thresholding"]
    H --> I["Label 3: Enhancing Tumor (ET)"]
    H --> J["Label 1: Tumor Core (TC / NCR)"]
    H --> K["Label 2: Whole Tumor (WT / ED)"]
```

### Tumor Sub-Region Priority & Mapping
1. **Label 3 (Enhancing Tumor - ET)**: High-priority hyper-intense active core on T1ce (overwrites underlying labels).
2. **Label 1 (Necrotic Core - NCR/NET)**: Non-enhancing necrotic structures within the tumor margin.
3. **Label 2 (Peritumoral Edema / Whole Tumor - ED/WT)**: Surrounding FLAIR hyper-intense infiltrative edema.

---

## 🖥️ System Requirements

| Component | Minimum Specification | Recommended Clinical Workstation |
| :--- | :--- | :--- |
| **Operating System** | Windows 10 (64-bit) | Windows 11 Pro / Enterprise (64-bit) |
| **Processor** | Intel Core i5 / AMD Ryzen 5 (4 Cores) | Intel Core i7/i9 / AMD Ryzen 7/9 (8+ Cores) |
| **System Memory (RAM)**| 16 GB RAM | 32 GB+ RAM (for multi-modality 3D loading) |
| **Graphics Card (GPU)**| CPU Fallback Mode (No GPU required) | NVIDIA GeForce RTX 3060 / 4070 / RTX A2000+ (8 GB+ VRAM) |
| **CUDA Toolchain** | Not Required for CPU Mode | CUDA 11.8+ / 12.1+ Runtime Driver |
| **Storage Space** | 6.0 GB Free Disk Space | NVMe SSD with 10 GB+ Free Space |

---

## 🚀 Installation & Quick Start

### Option A: Standalone Windows Installer
1. Download the compiled Windows installer: [`NeuroSegPro_Setup_v4.0.0.exe`](https://github.com/ASamy10/NeuroSeg-Pro/releases).
2. Run the setup wizard and accept Administrator privileges.
3. Launch via your Desktop Shortcut or Start Menu!

### Option B: Local Developer Installation
```powershell
# Clone the repository
git clone https://github.com/ASamy10/NeuroSeg-Pro.git
cd NeuroSeg-Pro

# Create and activate virtual environment
python -m venv .venv
.\.venv\Scripts\Activate.ps1

# Install runtime dependencies
pip install -r requirements.txt

# Run desktop application
python app\main.py
```

---

## 🏗️ Software Architecture

```text
NeuroSeg-Pro/
├── app/                                <-- Application Core Suite
│   ├── main.py                         <-- Application Entrypoint
│   ├── core/
│   │   ├── custom_model.py             <-- DynUNet & ParallelQuantumBottleneck
│   │   ├── inference.py                <-- Sliding-Window Clinical Engine
│   │   └── loader.py                   <-- NIfTI Multi-Modal Reader
│   └── ui/                             <-- PyQt5 Themeable Interface Components
├── assets/
│   ├── diagrams/                       <-- Architectural & Benchmark Figures
│   ├── icons/                          <-- SVG/PNG UI Icons
│   └── screenshots/                    <-- Application Clinical Screenshots
├── docs/
│   └── NeuroSeg_Pro_Graduation_Project_Presentation.pdf
├── research/
│   ├── README.md                       <-- Deep Learning Research Guide
│   ├── notebooks/
│   │   └── training-testing-any-hybrid-teacher-newlabels.ipynb
│   ├── preprocessing/
│   └── src/
├── install.ps1                         <-- Automated Runtime Bootstrapper
├── installer.iss                       <-- Inno Setup Compilation Script
├── NeuroSegPro.vbs                     <-- Windowless Silent VBS Launcher
└── requirements.txt                    <-- Python Package Specifications
```

---

## 👥 Authors, Supervisors & Academic Mentorship

### Core Engineering & Research Team
<table align="center" style="border: none; background: transparent;">
  <tr>
    <td align="center" width="220px">
      <a href="https://github.com/ASamy10">
        <img src="https://github.com/ASamy10.png" width="130px;" style="border-radius: 50%; border: 3px solid #0078D6; box-shadow: 0 4px 10px rgba(0,0,0,0.2);" alt="Ahmed Samy"/><br />
        <br />
        <sub><b>Ahmed Samy Mohsen</b></sub>
      </a><br />
      <small>Computer & Systems Engineering<br/>Deep Learning & AI Training</small>
    </td>
    <td align="center" width="220px">
      <a href="https://github.com/Omareldash">
        <img src="https://github.com/Omareldash.png" width="130px;" style="border-radius: 50%; border: 3px solid #0078D6; box-shadow: 0 4px 10px rgba(0,0,0,0.2);" alt="Omar Eldash"/><br />
        <br />
        <sub><b>Omar Mohammed Eldash</b></sub>
      </a><br />
      <small>Biomedical Engineering<br/>AI Model & Volumetric Inference</small>
    </td>
    <td align="center" width="220px">
      <a href="https://github.com/mohany203">
        <img src="https://github.com/mohany203.png" width="130px;" style="border-radius: 50%; border: 3px solid #0078D6; box-shadow: 0 4px 10px rgba(0,0,0,0.2);" alt="Mohamed Hany"/><br />
        <br />
        <sub><b>Mohamed Hany Gabr</b></sub>
      </a><br />
      <small>Biomedical Engineering<br/>Application Architect & GUI Suite</small>
    </td>
  </tr>
</table>

### Academic Supervision & Mentorship
* **Academic Mentor**: **Prof. Mohamed A. Al-Masni** — *Department of Artificial Intelligence, Sejong University, Seoul, South Korea* (Top 2% Stanford / Elsevier World Ranking Scientists).
* **Supervisors**:
  * **Dr. Rasha Ali** — *Computer and Systems Engineering Department*
  * **Dr. Rana Hossam** — *Biomedical Engineering Department*

---

## ⚖️ License
This project is open-source under the **MIT License**. See [`LICENSE`](LICENSE) for details.
