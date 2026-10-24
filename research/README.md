# 🔬 NeuroSeg Pro — Deep Learning & Research Suite

> **Advancing Generalizability in 3D Brain Tumor Segmentation Across Diverse Populations**  
> Under Academic Supervision of **Dr. Rasha Ali** (Computer and Systems Engineering) & **Dr. Rana Hossam** (Biomedical Engineering)  
> Academic Mentorship by **Prof. Mohamed A. Al-Masni** (Sejong University, Seoul, South Korea)

---

## 📌 Research Overview & Motivation

Brain tumors rank as the **5th most common cancer** worldwide and the **10th leading cause of cancer mortality**. Accurate delineation of sub-tumoral structures—**Necrotic Core (NCR)**, **Enhancing Tumor (ET)**, and **Peritumoral Edema (ED)**—is critical for surgical resection planning, radiation oncology, and chemotherapy tracking.

While automated deep learning models have shown high benchmark performance, clinical translation faces severe obstacles:
1. **Domain Generalizability Gap**: Discrepancies in MRI field strengths (1.5T vs. 3.0T), imaging protocols, scanner manufacturers, and patient demography cause conventional models to fail when applied out-of-distribution.
2. **Multi-Cohort Class Imbalance**: Training cohorts are heavily biased toward standardized adult high-income datasets, leading to severe performance drops in pediatric and underrepresented populations.
3. **Computational Complexity**: Modern 3D Vision Transformers (e.g., Swin UNETR) demand massive GPU memory and compute, hindering real-time inference on standard hospital workstations.

**NeuroSeg Pro** addresses these challenges through a unified framework combining **Hybrid Quantum-Classical Feature Extraction**, **Multi-Teacher Cross-Population Knowledge Distillation (KD)**, and **Demographic Stratified Batch Sampling**.

---

## 👥 Cohorts & Diverse Target Populations

Our evaluation spans **5 distinct tumor populations** totaling **2,824 multi-modal 3D MRI patient volumes**:

| Population Code | Clinical Description | Sample Count ($N$) | Key Domain Challenges |
| :--- | :--- | :---: | :--- |
| **GLI** | Adult Glioma (BraTS) | **1,251** | High heterogeneity, infiltrative margins |
| **MEN** | Intracranial Meningioma | **1,000** | Extra-axial dural attachment, calcifications |
| **MET** | Brain Metastases | **328** | Multifocal lesions, variable size and edema |
| **SSA** | Sub-Saharan African Glioma | **146** | Lower SNR, scanner protocol variability |
| **PED** | Pediatric Brain Tumors | **99** | Posterior fossa predilection, distinct histology |

<p align="center">
  <img src="../assets/diagrams/cohort_anatomical_diversity.png" alt="Morphological Diversity Across Populations" width="95%"/>
  <br/>
  <em>Representative MRI volumes showcasing morphological and anatomical heterogeneity across the five target populations.</em>
</p>

### Sub-Region Label Hierarchy
Input sequences consist of four skull-stripped 3D MRI modalities: **T1**, **T1ce**, **T2**, and **FLAIR** ($4 \times 128 \times 128 \times 128$ voxel patches). Segmentation outputs are mapped to nested clinical regions:
* **Whole Tumor (WT)**: Necrotic Core + Enhancing Tumor + Peritumoral Edema ($\text{WT} = \text{NCR} \cup \text{ET} \cup \text{ED}$)
* **Tumor Core (TC)**: Necrotic Core + Enhancing Tumor ($\text{TC} = \text{NCR} \cup \text{ET}$)
* **Enhancing Tumor (ET)**: Active proliferating hyper-intense margin on T1ce

---

## ⚖️ Stratified Batch Sampling (Fairness Strategy)

To counteract catastrophic demographic bias where high-volume cohorts (GLI, MEN) drown out smaller cohorts (SSA, PED), we implement a **cyclical stratified batch sampler**:

<p align="center">
  <img src="../assets/diagrams/stratified_batch_sampling.png" alt="Stratified Batch Sampling" width="60%"/>
  <br/>
  <em>Balanced mini-batch formation: every training iteration samples uniformly across all 5 populations, with minority cohorts sampled cyclically with replacement.</em>
</p>

This guarantees that gradients computed during model updates assign equal weighting to all sub-populations regardless of original dataset size.

---

## ⚛️ Hybrid Quantum-Classical DynUNet Architecture

NeuroSeg Pro replaces the deepest spatial bottleneck of a 3D DynUNet with a **Parallel Parameterized Quantum Circuit (PQC)** implemented via [PennyLane](https://pennylane.ai/):

<p align="center">
  <img src="../assets/diagrams/quantum_dynunet_architecture.png" alt="Parallel Quantum Bottleneck Architecture" width="95%"/>
</p>

### Quantum Bottleneck Mechanics
1. **Adaptive Spatial Pooling**: At the deepest encoder stage ($384 \times 4 \times 4 \times 4$), features are pooled down to $384 \times 1 \times 1 \times 1$.
2. **Parallel Quantum Circuits**: Features are split across two parallel PennyLane quantum layers:
   * **Qubits**: $n = 10$ wires
   * **Layers**: $L = 6$ to $8$ strongly entangling variational layers
   * **State Preparation**: `qml.AngleEmbedding(inputs, wires=range(n_qubits))`
   * **Entanglement**: `qml.StronglyEntanglingLayers(weights, wires=range(n_qubits))`
   * **Measurement**: Expectation values $\langle Z_i \rangle$ for $i \in \{0, \dots, n-1\}$
3. **Linear Projection & Concatenation**: Quantum expectation values are concatenated and projected back to the decoder feature space ($512 \times 2 \times 2 \times 2$), restoring 3D spatial resolution via transposed convolutions.

### Proof-of-Concept Validation (Liver Decathlon Task03)
Before applying to multi-modal brain MRI, the hybrid architecture was validated on 3D abdominal CT liver segmentation:
* **Train Dice**: $0.9332$ vs. $0.9262$ (+0.76%)
* **Validation Dice**: $0.9360$ vs. $0.9229$ (+1.42%)
* **Parameters**: **$66.92\text{M}$** vs. $137.66\text{M}$ (**-51.39% reduction**)

---

## 🎓 Multi-Teacher Knowledge Distillation (KD)

Deploying separate large teacher models for every tumor type is clinically impractical. We distill 5 specialized teacher models into a single, compact **Generalized Student Model**:

<p align="center">
  <img src="../assets/diagrams/multi_cohort_kd_pipeline.jpg" alt="Multi-Teacher KD Pipeline" width="85%"/>
</p>

### Detailed Distillation Objective
The student network is optimized through a compound loss integrating **Deep Supervision Segmentation**, **Logits Distillation**, and **CBAM Intermediate Feature Matching**:

<p align="center">
  <img src="../assets/diagrams/knowledge_distillation_detailed_loss.png" alt="Detailed Knowledge Distillation Formulation" width="90%"/>
</p>

$$\mathcal{L}_{\text{total}} = \mathcal{L}_{\text{seg}}^{\text{DS}} + \alpha \, \mathcal{L}_{\text{logits}}^{\text{DS}} + \beta \, \mathcal{L}_{\text{KL}}$$

1. **Deep Supervision Segmentation Loss ($\mathcal{L}_{\text{seg}}^{\text{DS}}$)**:
   Computed at the last 3 decoder stages against ground truth labels:
   $$\mathcal{L}_{\text{seg}} = \mathcal{L}_{\text{Dice}}(p, y) + \mathcal{L}_{\text{BCE}}(p, y)$$
2. **Logits Distillation Loss ($\mathcal{L}_{\text{logits}}^{\text{DS}}$)**:
   Aligns student and teacher probability distributions using temperature-scaled sigmoids ($T$):
   $$\mathcal{L}_{\text{logits}} = \text{BCE}\left(\sigma(z_S / T), \, \sigma(z_T / T)\right)$$
3. **CBAM Attention-Guided Feature Matching ($\mathcal{L}_{\text{KL}}$)**:
   Channel and Spatial Attention (CBAM) modules refine intermediate bottleneck embeddings, transferring spatial context via Kullback-Leibler divergence:
   $$\mathcal{L}_{\text{KL}} = \text{KL}\left(\text{Softmax}(F_T) \,||\, \text{LogSoftmax}(F_S)\right)$$

---

## 📊 Experimental Results & Benchmarks

### 1. Teacher Models: Hybrid vs. Classical

| Target Population | Metric | Hybrid Teacher (Proposed) | Classical Teacher | Difference (%) |
| :--- | :--- | :---: | :---: | :---: |
| **Adult Glioma (GLI)** | Average Dice<br/>Average HD95 | **0.8864**<br/>**6.59 mm** | 0.8823<br/>6.20 mm | **+0.46%**<br/>+6.22% |
| **Sub-Saharan Africa (SSA)** | Average Dice<br/>Average HD95 | 0.7906<br/>14.42 mm | **0.8013**<br/>**13.51 mm** | -1.34%<br/>+6.78% |
| **Pediatric (PED)** | Average Dice<br/>Average HD95 | **0.7162**<br/>**20.26 mm** | 0.6587<br/>35.52 mm | **+8.73%**<br/>**-42.96% (better)** |
| **Meningioma (MEN)** | Average Dice<br/>Average HD95 | **0.8262**<br/>**24.89 mm** | 0.8247<br/>35.34 mm | **+0.18%**<br/>**-29.58% (better)** |
| **Metastases (MET)** | Average Dice<br/>Average HD95 | **0.6037**<br/>**27.56 mm** | 0.5627<br/>47.87 mm | **+7.29%**<br/>**-42.43% (better)** |

> Notice the dramatic boundary accuracy gains on difficult cohorts: **HD95 reduced by over 42% on Pediatric and Metastatic cases**!

### 2. Multi-Model Qualitative Comparison

<p align="center">
  <img src="../assets/diagrams/qualitative_benchmark_comparison.png" alt="Qualitative Segmentation Benchmark" width="95%"/>
</p>

The proposed generalized student model consistently outperforms Continual Learning (CL, RCL), Ensembles (Hard Voting, Weighted Voting, Uncertainty-Guided Fusion), and baseline Fine-tuned models across all five population groups.

---

## 💻 Running the Research Notebook

The complete end-to-end training and evaluation pipeline is contained in:
[`notebooks/training-testing-any-hybrid-teacher-newlabels.ipynb`](notebooks/training-testing-any-hybrid-teacher-newlabels.ipynb)

### Prerequisites
```bash
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
pip install "monai[nibabel]==1.3.2" pennylane clearml tqdm
```

### Notebook Sections
1. **Dependencies & Environment Setup**: Installs PyTorch cu121, MONAI 1.3.2, and PennyLane.
2. **Dataset & Preprocessing (`CustomDataset3D`)**: Resampling, intensity normalization, foreground cropping, and spatial resizing with preserved aspect ratio.
3. **DynUNet with Parallel Quantum Bottleneck**: Definition of `UnetBasicBlock`, PennyLane `quantum_circuit`, `QuantumLayer`, and 6-stage `DynUNet`.
4. **Compound Loss Function**: Combination of DiceLoss and BCEWithLogitsLoss with nested tumor masking.
5. **ClearML Experiment Tracking**: Automated logging of scalar metrics, validation Dice curves, and model checkpoints.
6. **Volumetric Evaluation**: Sliding-window inference with `monai.metrics.DiceMetric` and `HausdorffDistanceMetric` (HD95).
