# SpotsVoronoiCreate — User Guide

**Script:** `SpotsVoronoiCreate.m`  
**Author:** Dr Ellie Cho, Biological Optical Microscopy Platform (BOMP), The University of Melbourne  
**Contact:** ellie.cho@unimelb.edu.au | bomp-enquiries@unimelb.edu.au  
**Version:** 1.0 — March 2026 | Tested in Imaris 10.2

> **Citation requirement:** If results arising from this script are used in any publication, Dr Ellie Cho should be considered as an author.

---

## Overview

This script generates a 3D Voronoi tessellation from a spots object in Imaris, creating a new labeled image channel. Each voxel in the volume is assigned to its nearest spot, partitioning three-dimensional space into discrete regions — one per spot.

The resulting channel is a **labeled map**: every voxel's intensity value identifies which spot it belongs to. This labeled map is designed to be used with downstream masking (applied manually in Imaris) and surface creation via `CreateSurfacesFromLabeledMap.m`.

**Example use case:** Partitioning Rosenthal's canal into electrode-specific regions of interest. Spots placed at electrode centres are used to divide the cochlear space so that auditory neurons can be counted within the region associated with each electrode.

---

## Prerequisites

- At least one **Spots** object with a minimum of 2 spots
- Adequate RAM for your dataset size
- The dataset bit depth should be sufficient to represent all spot IDs (see [Bit depth dialog](#dialog-2-bit-depth-warning-if-applicable))

---

## Installation

1. Copy `SpotsVoronoiCreate.m` into your Imaris XTensions folder
2. In Imaris: **Edit → Preferences → Custom Tools**, confirm the folder path is listed
3. Restart Imaris

The script will appear under: **Spots → XT Tab → Create Voronoi Channel**

---

## Workflow

### Step 1: Prepare spots

Place one spot at the position of each structure whose spatial territory you want to define. For electrode-based analysis, this means placing one spot at each electrode centre. Spots should cover the full length of the region of interest.

The script processes spots in the **original Imaris spot index order** (the order in which they were created), which becomes important for the ghost point extrapolation at the endpoints.

> **Minimum:** 2 spots are required.

---

### Step 2: Select the spots object

Select the spots object in the Imaris scene before running the script. If no spots object is selected, the script will automatically use the first spots object found in the scene.

---

### Step 3: Run the script

Navigate to **Spots → XT Tab → Create Voronoi Channel**.

---

### Step 4: Intensity assignment dialog

**Dialog: "How should Voronoi cell intensities be assigned?"**

This dialog determines what intensity value is written into the Voronoi channel for each spot's region.

| Option | Intensity value assigned | When to use |
|---|---|---|
| **Sequential (1, 2, 3...)** | 1 for the first spot in index order, 2 for the second, and so on | Default choice; simpler to interpret |
| **Match Imaris Spot ID** | The actual Imaris Spot ID for each spot | Use when the downstream analysis requires matching back to specific Imaris-tracked spots |

> **Which should I choose?**  
> For most workflows, **Sequential** is sufficient and produces a cleaner channel (intensity values start at 1 and increase without gaps). Choose **Match Imaris Spot ID** only if you need to cross-reference the Voronoi regions against Imaris statistics or other Imaris objects that use the same Spot IDs.

The two extrapolated ghost points are always assigned special IDs:
- Ghost point before the first spot → intensity **0**
- Ghost point after the last spot → intensity **N+1** (sequential) or **max ID + 1** (Imaris ID)

These border regions are outside the range of real spots and will be excluded by the downstream surface masking steps.

**Example images**

*[Insert image: the dialog box showing the two intensity assignment options]*

*[Insert image: the resulting Voronoi channel displayed in Imaris (yellow), showing distinct intensity regions around each spot]*

---

### Dialog 2: Bit depth warning (if applicable)

This dialog only appears when the maximum intensity value required exceeds the current dataset bit depth.

**Dialog: "The maximum intensity value exceeds the current dataset bit depth"**

| Option | Behaviour |
|---|---|
| **Upgrade to 16-bit** | The new channel is written at 16-bit depth, accommodating up to 65,535 intensity values |
| **Keep 8-bit (values above 255 will saturate)** | The channel stays at 8-bit; any Spot ID above 255 will be clipped to 255 |

> **When does this appear?**  
> - With **Sequential**, this dialog appears if you have more than 255 spots.  
> - With **Match Imaris Spot ID**, this appears if the largest Imaris Spot ID in your spots object exceeds 255.  
> Upgrading to 16-bit is recommended whenever this dialog appears.

---

### Step 5: Output

A new channel is added to the Imaris dataset (yellow by default), named:

- `Voronoi Cells (sequential)` — if sequential intensity was chosen
- `Voronoi Cells (Imaris ID)` — if Imaris Spot ID matching was chosen

The channel range is automatically set from 0 to the maximum spot ID (or N+1 for sequential).

> **Important:** Save your Imaris file immediately after the script completes. The Voronoi channel is the starting point for all downstream masking steps.

**Example images**

*[Insert image: the completed Voronoi channel overlaid on the LSFM image, with the electrode spot positions visible, showing colour-coded regions extending through the tissue volume]*

*[Insert image: a slice view through the Voronoi channel showing distinct intensity steps at each Voronoi boundary]*

---

## Memory and performance

The tessellation is computed in chunks of 10 z-slices to keep memory usage within practical limits for large datasets. For a typical dataset (e.g., 2758 × 3496 × 530 voxels at uint16), peak memory usage during this stage is approximately 11 GB. The MATLAB console prints the estimated memory requirement and available physical memory (on Windows) before processing begins.

Processing time scales with dataset volume and number of spots. For the dataset dimensions above with 8 spots, processing takes approximately 10–20 minutes.

---

## What happens next

The Voronoi channel on its own covers the entire image volume, including regions outside the tissue. Before generating surfaces from it, you need to restrict it to the region of interest using Imaris masking tools. Refer to the workflow documentation for the recommended masking sequence:

1. **Surface-based masking** — mask the Voronoi channel with an anatomical surface (e.g., Rosenthal's canal) to retain only voxels within the structure of interest
2. **Spot-based masking** (optional) — mask the result with enlarged spots (`SpotsResizeDiameter.m`) to further restrict the region to the vicinity of the electrodes
3. **Surface creation** — convert the masked labeled channel to individual surface objects (`CreateSurfacesFromLabeledMap.m`)

**Example images**

*[Insert image: side-by-side comparison of the Voronoi channel before masking (full volume) and after surface-based masking (restricted to Rosenthal's canal)]*

---

## Troubleshooting

| Problem | Likely cause | Solution |
|---|---|---|
| Script not visible in XT tab | XTensions folder not configured | Check Imaris Preferences → Custom Tools |
| "Need at least 2 spots" error | Fewer than 2 spots in the object | Add more spots |
| Voronoi boundaries do not align with expected positions | Ghost point extrapolation pulls boundary | This is expected at the endpoints; apply masking to restrict the region |
| Out of memory error | Dataset too large for available RAM | Increase virtual memory, or process on a workstation with more RAM |
| Intensities appear clipped | Spot IDs exceed 8-bit range | Re-run and choose "Upgrade to 16-bit" |
