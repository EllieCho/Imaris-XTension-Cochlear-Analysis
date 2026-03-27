# SpotsResizeDiameter — User Guide

**Script:** SpotsResizeDiameter.m  
**Author:** Dr Ellie Cho, Biological Optical Microscopy Platform (BOMP), The University of Melbourne  
**Contact:** ellie.cho@unimelb.edu.au | bomp-enquiries@unimelb.edu.au  
**Version:** 1.0 — March 2026 | Tested in Imaris 10.2

## Manuscript
 
These scripts are described in full in the following manuscript, currently under preparation:
 
> Trang EP, Cho E, Wise A, Segal-Wasserman G, Fallon JB. *A detailed protocol for three-dimensional analysis of a chronically implanted and stimulated cochlea.* **Manuscript in preparation.**
 
A formal citation and DOI will be added here upon publication.

---

## Overview

This script creates a new spots object in Imaris where all spots are resized to a uniform diameter specified by the user. The positions, time indices, and colour of the original spots are preserved; only the radius is changed.

The primary purpose of this script is to create enlarged spot volumes for use as a **spatial mask**. In the Voronoi tessellation workflow, the enlarged spots are used to restrict the Voronoi channel to a defined radius around each spot (electrode contact), excluding regions of the tissue that are too far from the electrode array to be relevant.

**Example use case:** After generating a Voronoi channel restricted to Rosenthal's canal, enlarge electrode spots to 2000 μm diameter and use the resulting enlarged spots object to mask the Voronoi channel, retaining only Voronoi regions within 1000 μm of any electrode centre.

---

## Prerequisites

- At least one **Spots** object in the Imaris scene
- Familiarity with Imaris channel masking (**Edit → Mask Channel**)

---

## Installation

1. Copy `SpotsResizeDiameter.m` into your Imaris XTensions folder
2. In Imaris: **Edit → Preferences → Custom Tools**, confirm the folder path is listed
3. Restart Imaris

The script will appear under: **Spots → XT Tab → Resize Spots to Diameter**

---

## Workflow

### Step 1: Select the spots object

Select the spots object you want to resize in the Imaris scene. If no spots object is selected, the script will automatically use the first spots object found in the scene.

---

### Step 2: Run the script

Navigate to **Spots → XT Tab → Resize Spots to Diameter**.

---

### Step 3: Diameter input dialog

**Dialog: Resize Spots Parameters**

| Field | Description | Default |
|---|---|---|
| New spot diameter (micrometres) | The diameter applied uniformly to all spots in the object | 2000 |

> **Choosing a diameter:**  
> The appropriate value depends on how far from each spot you want to include in your analysis. A diameter of 2000 μm creates a sphere of radius 1000 μm around each spot centre. For cochlear electrode analysis, this is used to restrict the Voronoi tessellation to the region of tissue directly adjacent to the electrode array, excluding the far end of Rosenthal's canal that is distant from any electrode.  
> The value should be chosen based on the anatomy of your sample and the scale of your dataset.

> **Units:** The value is always in micrometres, regardless of the voxel size of your dataset.

**Example images**

*[Insert image: the diameter input dialog, showing the default value of 2000 and the prompt text]*

*[Insert image: side-by-side view in Imaris showing the original small spots (at electrode centres) and the enlarged spots after running the script, demonstrating the size difference in the 3D scene]*

---

### Step 4: Output

A new spots object is added to the Imaris scene, named:

```
[OriginalSpotsName]_Resized_D2000.0um
```

where `2000.0` is replaced with whatever diameter you entered.

The new spots object retains:
- All original spot positions (XYZ coordinates)
- All original time indices
- The original spots colour

The original spots object is unchanged.

**Example images**

*[Insert image: the Imaris scene tree showing both the original spots and the newly created resized spots object]*

*[Insert image: a 3D view showing the enlarged spots overlapping the Voronoi channel, illustrating the spatial relationship between the masking volume and the Voronoi regions]*

---

## What happens next

After creating the enlarged spots, use the **Imaris Mask Channel** function to apply them as a mask:

1. Select the enlarged spots object in the scene
2. Go to **Edit → Mask Channel**
3. **Channel to mask:** select the surface-masked Voronoi channel (from the previous masking step)
4. Tick **Duplicate channel before applying mask**
5. Select **Constant inside/outside**
6. Tick **Set voxel intensity outside surface to: 0**
7. Click **OK**
8. Rename the resulting channel (e.g., `Voronoi Cells (Surface + Spots Masked)`)
9. Save your file

**Example images**

*[Insert image: the Imaris Mask Channel dialog box, with annotations indicating the correct settings for each field]*

*[Insert image: the Voronoi channel after spot-based masking, showing the regions that were retained versus excluded]*

---

## Troubleshooting

| Problem | Likely cause | Solution |
|---|---|---|
| Script not visible in XT tab | XTensions folder not configured | Check Imaris Preferences → Custom Tools |
| "Diameter must be greater than 0" error | Zero or negative value entered | Enter a positive diameter value |
| "Please create some spots" error | No spots object in the scene | Create a spots object first |
| Enlarged spots do not appear in the scene | Script completed but view not refreshed | Click elsewhere in the scene tree to trigger a refresh |
| Mask removes too much / too little of the Voronoi channel | Diameter not matched to dataset scale | Adjust the diameter and re-run; delete the unwanted resized spots object first |
