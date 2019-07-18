#!/bin/bash
#~ND~FORMAT~MARKDOWN~
#~ND~START~
#
# # RestfMRILevel1.sh
#
# ## Copyright (c) 2011-2019 The Human Connectome Project and The Connectome Coordination Facility
#
# ## Author(s)
#
# * Timothy Hendrickson, University of Minnesota Informatics Institute, Minneapolis, Minnesota
# ## Product
#
# [Human Connectome Project][HCP] (HCP) Pipelines
#
# ## License
#
# See the [LICENSE](https://github.com/Washington-University/Pipelines/blob/master/LICENCE.md) file
#
# ## Description
#
# This script runs Level 1 Resting State Seed fMRI Analysis.
#
# <!-- References -->                                                                                                             
# [HCP]: http://www.humanconnectome.org
# [FSL]: http://fsl.fmrib.ox.ac.uk
#
#~ND~END~   


set -e
set -x


# Requirements for this script
#  installed versions of FSL 6.0.1
#  environment: FSLDIR, CARET7DIR 


########################################## PREPARE FUNCTIONS ########################################## 

export PATH=/usr/local/fsl/bin:${PATH}

show_tool_versions()
{
	# Show wb_command version
	echo "TOOL_VERSIONS: Showing Connectome Workbench (wb_command) version"
	${CARET7DIR}/wb_command -version

	# Show FSL version
	echo "TOOL_VERSION: Showing FSL version"
	cat /usr/local/fsl/etc/fslversion
}


########################################## READ_ARGS ##################################

# Set variables from positional arguments to command line
Subject="$1"
ResultsFolder="$2"
ROIsFolder="$3"
DownSampleFolder="$4"
LevelOnefMRIName="$5"
LevelOnefsfName="$6"
LowResMesh="$7"
GrayordinatesResolution="$8"
OriginalSmoothingFWHM="$9"
Confound="${10}"
FinalSmoothingFWHM="${11}"
TemporalFilter="${12}"
VolumeBasedProcessing="${13}"
RegName="${14}"
Parcellation="${15}"
ParcellationFile="${16}"
seedROI="${17}"

# Explicitly set tool name for logging
g_script_name=`basename ${0}`
echo "Script name: ${g_script_name}"
echo "DownSampleFolder: ${DownSampleFolder}"
echo "LevelOnefMRIName: ${LevelOnefMRIName}"
echo "LevelOnefsfName: ${LevelOnefsfName}"
echo "LowResMesh: ${LowResMesh}"
echo "GrayordinatesResolution: ${GrayordinatesResolution}"
echo "OriginalSmoothingFWHM: ${OriginalSmoothingFWHM}"
echo "Confound: ${Confound}"
echo "FinalSmoothingFWHM: ${FinalSmoothingFWHM}"
echo "TemporalFilter: ${TemporalFilter}"
echo "VolumeBasedProcessing: ${VolumeBasedProcessing}"
echo "RegName: ${RegName}"
echo "Parcellation: ${Parcellation}"
echo "ParcellationFile: ${ParcellationFile}"
echo "seedROI: ${seedROI}" 

show_tool_versions

########################################## MAIN ##################################

##### DETERMINE ANALYSES TO RUN (DENSE, PARCELLATED, VOLUME) #####

# initialize run variables
runParcellated=false; runVolume=false; runDense=false;

# Determine whether to run Parcellated, and set strings used for filenaming
if [ "${Parcellation}" != "NONE" ] ; then
	# Run Parcellated Analyses
	runParcellated=true;
	ParcellationString="_${Parcellation}"
	Extension="ptseries.nii"
	echo "MAIN: DETERMINE_ANALYSES: Parcellated Analysis requested"
fi

# Determine whether to run Dense, and set strings used for filenaming
if [ "${Parcellation}" = "NONE" ]; then
	# Run Dense Analyses
	runDense=true;
	ParcellationString=""
	Extension="dtseries.nii"
	echo "MAIN: DETERMINE_ANALYSES: Dense Analysis requested"
fi

# Determine whether to run Volume, and set strings used for filenaming
if [ "$VolumeBasedProcessing" = "YES" ] ; then
	runVolume=true;
	echo "MAIN: DETERMINE_ANALYSES: Volume Analysis requested"
fi


##### SET_NAME_STRINGS: smoothing and filtering string variables used for file naming #####
OriginalSmoothString="_s${OriginalSmoothingFWHM}"
FinalSmoothingString="_s${FinalSmoothingFWHM}"
TemporalFilterString="_hp${TemporalFilter}"
# Set variables used for different registration procedures
if [ "${RegName}" != "NONE" ] ; then
	RegString="_${RegName}"
else
	RegString=""
fi

echo "MAIN: SET_NAME_STRINGS: OriginalSmoothingString: ${OriginalSmoothingString}"
echo "MAIN: SET_NAME_STRINGS: FinalSmoothingString: ${FinalSmoothingString}"
echo "MAIN: SET_NAME_STRINGS: TemporalFilterString: ${TemporalFilterString}"
echo "MAIN: SET_NAME_STRINGS: RegString: ${RegString}"
echo "MAIN: SET_NAME_STRINGS: ParcellationString: ${ParcellationString}"
echo "MAIN: SET_NAME_STRINGS: Extension: ${Extension}"


##### IMAGE_INFO: DETERMINE TR AND SCAN LENGTH #####
# Caution: Reading information for Parcellated and Volume analyses from original CIFTI file
# Extract TR information from input time series files
TR_vol=`${CARET7DIR}/wb_command -file-information ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${RegString}${TemporalFilterString}_clean.dtseries.nii -no-map-info -only-step-interval`
echo "MAIN: IMAGE_INFO: TR_vol: ${TR_vol}"

# Extract number of time points in CIFTI time series file
npts=`${CARET7DIR}/wb_command -file-information ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${RegString}${TemporalFilterString}_clean.dtseries.nii -no-map-info -only-number-of-maps`
echo "MAIN: IMAGE_INFO: npts: ${npts}"


##### MAKE_DESIGNS: MAKE DESIGN FILES #####

# Create output .feat directory ($FEATDir) for this analysis
FEATDir="${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefsfName}${RegString}${TemporalFilterString}${FinalSmoothingString}${ParcellationString}_level1_${seedROI}_ROI.feat"
echo "MAIN: MAKE_DESIGNS: FEATDir: ${FEATDir}"
if [ -e ${FEATDir} ] ; then
	rm -r ${FEATDir}
	mkdir ${FEATDir}
else
	mkdir -p ${FEATDir}
fi

taskfile_base=`basename $taskfile`

# get the number of time points in the image file
FMRI_NPTS=`fslinfo ${taskfile} | grep -w 'dim4' | awk '{print $2}'`

# now the TR in the image file
FMRI_TR=`fslinfo ${taskfile} | grep -w 'pixdim4' | awk '{print $2}'`

# now number of voxels in image file
FMRI_VOXS=`fslstats ${taskfile} -v | awk '{print $1} '`

# modify the destination by putting in the correct number of time points
sed -i "s/NTPS/${FMRI_NPTS}/" ${outdir}/${taskname}${TemporalFilterString}${OriginalSmoothingString}_level1.fsf
sed -i "s:TRS:${FMRI_TR}:g" ${outdir}/${taskname}${TemporalFilterString}${OriginalSmoothingString}_level1.fsf
sed -i "s:TOTVOXELS:${FMRI_VOXS}:g" ${outdir}/${taskname}${TemporalFilterString}${OriginalSmoothingString}_level1.fsf
sed -i "s:HPASS:${temporalfilter}:g" ${outdir}/${taskname}${TemporalFilterString}${OriginalSmoothingString}_level1.fsf
sed -i "s:FEATFILE:${taskfile_base}:g" ${outdir}/${taskname}${TemporalFilterString}${OriginalSmoothingString}_level1.fsf
sed -i "s:REGRESSOR:${regressor_file}:g" ${outdir}/${taskname}${TemporalFilterString}${OriginalSmoothingString}_level1.fsf


### Edit fsf file to record the parameters used in this analysis
# Copy template fsf file into $FEATDir
echo "MAIN: MAKE_DESIGNS: Copying fsf file to .feat directory"
cp ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefsfName}${TemporalFilterString}${OriginalSmoothString}_level1.fsf ${FEATDir}/design.fsf

# Change the highpass filter string to the desired highpass filter
echo "MAIN: MAKE_DESIGNS: Change design.fsf: Set highpass filter string to the desired highpass filter to ${TemporalFilter}"
sed -i -e "s|set fmri(paradigm_hp) \"200\"|set fmri(paradigm_hp) \"${TemporalFilter}\"|g" ${FEATDir}/design.fsf

# Change smoothing to be equal to additional smoothing in FSF file
echo "MAIN: MAKE_DESIGNS: Change design.fsf: Set smoothing to be equal to final smoothing to ${FinalSmoothingFWHM}"
sed -i -e "s|set fmri(smooth) \"2\"|set fmri(smooth) \"${FinalSmoothingFWHM}\"|g" ${FEATDir}/design.fsf

# Change output directory name to match total smoothing and highpass
echo "MAIN: MAKE_DESIGNS: Change design.fsf: Change string in output directory name to ${RegString}${TemporalFilterString}${FinalSmoothingString}${ParcellationString}_level1"
sed -i -e "s|_hp2000_s2|${RegString}${TemporalFilterString}${FinalSmoothingString}${ParcellationString}_level1|g" ${FEATDir}/design.fsf

# find current value for npts in template.fsf
fsfnpts=`grep "set fmri(npts)" ${FEATDir}/design.fsf | cut -d " " -f 3 | sed 's|"||g'`;

# Ensure number of time points in fsf matches time series image
if [ "$fsfnpts" -eq "$npts" ] ; then
	echo "MAIN: MAKE_DESIGNS: Change design.fsf: Scan length matches number of timepoints in template.fsf: ${fsfnpts}"
else
	echo "MAIN: MAKE_DESIGNS: Change design.fsf: Warning! Scan length does not match template.fsf!"
	echo "MAIN: MAKE_DESIGNS: Change design.fsf: Warning! Changing Number of Timepoints in fsf (""${fsfnpts}"") to match time series image (""${npts}"")"
	sed -i -e  "s|set fmri(npts) \"\?${fsfnpts}\"\?|set fmri(npts) ${npts}|g" ${FEATDir}/design.fsf
fi


### Use fsf to create additional design files used by film_gls
echo "MAIN: MAKE_DESIGNS: Create design files, model confounds if desired"
# Determine if there is a confound matrix text file (e.g., output of fsl_motion_outliers)
confound_matrix="";
if [ "$Confound" != "NONE" ] ; then
	confound_matrix=$( ls -d ${ResultsFolder}/${LevelOnefMRIName}/${Confound} 2>/dev/null )
fi

# Run feat_model inside $FEATDir
cd $FEATDir # so feat_model can interpret relative paths in fsf file
feat_model ${FEATDir}/design ${confound_matrix}; # $confound_matrix string is blank if file is missing
cd $OLDPWD	# OLDPWD is shell variable previous working directory

# Set variables for additional design files
DesignMatrix=${FEATDir}/design.mat
DesignContrasts=${FEATDir}/design.con
DesignfContrasts=${FEATDir}/design.fts

# An F-test may not always be requested as part of the design.fsf
ExtraArgs=""
if [ -e "${DesignfContrasts}" ] ; then
	ExtraArgs="$ExtraArgs --fcon=${DesignfContrasts}"
fi


##### SMOOTH_OR_PARCELLATE: APPLY SPATIAL SMOOTHING (or parcellation) #####

### Parcellate data if a Parcellation was provided
# Parcellation may be better than adding spatial smoothing to dense time series.
# Parcellation increases sensitivity and statistical power, but avoids blurring signal 
# across region boundaries into adjacent, non-activated regions.
echo "MAIN: SMOOTH_OR_PARCELLATE: PARCELLATE: Parcellate data if a Parcellation was provided"
if $runParcellated; then
	echo "MAIN: SMOOTH_OR_PARCELLATE: PARCELLATE: Parcellating data"
	echo "MAIN: SMOOTH_OR_PARCELLATE: PARCELLATE: Notice: currently parcellated time series has $FinalSmoothingString in file name, but no additional smoothing was applied!"
	# FinalSmoothingString in parcellated filename allows subsequent commands to work for either dtseries or ptseries
	${CARET7DIR}/wb_command -cifti-parcellate ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${RegString}${TemporalFilterString}_clean.dtseries.nii ${ParcellationFile} COLUMN ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${RegString}${TemporalFilterString}${FinalSmoothingString}${ParcellationString}_clean.ptseries.nii
fi

### Apply spatial smoothing to CIFTI dense analysis
if $runDense ; then
	if [ "$FinalSmoothingFWHM" -gt "$OriginalSmoothingFWHM" ] ; then
		# Some smoothing was already conducted in fMRISurface Pipeline. To reach the desired
		# total level of smoothing, the additional spatial smoothing added here must be reduced
		# by the original smoothing applied earlier
		AdditionalSmoothingFWHM=`echo "sqrt(( $FinalSmoothingFWHM ^ 2 ) - ( $OriginalSmoothingFWHM ^ 2 ))" | bc -l`
		AdditionalSigma=`echo "$AdditionalSmoothingFWHM / ( 2 * ( sqrt ( 2 * l ( 2 ) ) ) )" | bc -l`
		echo "MAIN: SMOOTH_OR_PARCELLATE: SMOOTH_CIFTI: AdditionalSmoothingFWHM: ${AdditionalSmoothingFWHM}"
		echo "MAIN: SMOOTH_OR_PARCELLATE: SMOOTH_CIFTI: AdditionalSigma: ${AdditionalSigma}"
		echo "MAIN: SMOOTH_OR_PARCELLATE: SMOOTH_CIFTI: Applying additional surface smoothing to CIFTI Dense data"
		${CARET7DIR}/wb_command -cifti-smoothing ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${RegString}${TemporalFilterString}_clean.dtseries.nii ${AdditionalSigma} ${AdditionalSigma} COLUMN ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${RegString}${TemporalFilterString}${FinalSmoothingString}_clean.dtseries.nii -left-surface ${DownSampleFolder}/${Subject}.L.midthickness.${LowResMesh}k_fs_LR.surf.gii -right-surface ${DownSampleFolder}/${Subject}.R.midthickness.${LowResMesh}k_fs_LR.surf.gii
	else
		if [ "$FinalSmoothingFWHM" -eq "$OriginalSmoothingFWHM" ]; then
			echo "MAIN: SMOOTH_OR_PARCELLATE: SMOOTH_CIFTI: No additional surface smoothing requested for CIFTI Dense data"
		else
			echo "MAIN: SMOOTH_OR_PARCELLATE: SMOOTH_CIFTI: WARNING: For CIFTI Dense data, the surface smoothing requested \($FinalSmoothingFWHM\) is LESS than the surface smoothing already applied \(${OriginalSmoothingFWHM}\)."
			echo "MAIN: SMOOTH_OR_PARCELLATE: SMOOTH_CIFTI: Continuing analysis with ${OriginalSmoothingFWHM} of total surface smoothing."
		fi
		cp ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${RegString}${TemporalFilterString}_clean.dtseries.nii ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${RegString}${TemporalFilterString}${FinalSmoothingString}_clean.dtseries.nii
	fi
fi

### Apply spatial smoothing to volume analysis
if $runVolume ; then
	echo "MAIN: SMOOTH_OR_PARCELLATE: SMOOTH_NIFTI: Standard NIFTI Volume-based Processsing"

	#Add edge-constrained volume smoothing
	echo "MAIN: SMOOTH_OR_PARCELLATE: SMOOTH_NIFTI: Add edge-constrained volume smoothing"
	FinalSmoothingSigma=`echo "$FinalSmoothingFWHM / ( 2 * ( sqrt ( 2 * l ( 2 ) ) ) )" | bc -l`
	InputfMRI=${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}
	InputSBRef=${InputfMRI}_SBRef
	fslmaths ${InputSBRef} -bin ${FEATDir}/mask_orig
	fslmaths ${FEATDir}/mask_orig -kernel gauss ${FinalSmoothingSigma} -fmean ${FEATDir}/mask_orig_weight -odt float
	fslmaths ${InputfMRI} -kernel gauss ${FinalSmoothingSigma} -fmean \
	  -div ${FEATDir}/mask_orig_weight -mas ${FEATDir}/mask_orig \
	  ${FEATDir}/${LevelOnefMRIName}${FinalSmoothingString} -odt float

	#Add volume dilation
	#
	# For some subjects, FreeSurfer-derived brain masks (applied to the time 
	# series data in IntensityNormalization.sh as part of 
	# GenericfMRIVolumeProcessingPipeline.sh) do not extend to the edge of brain
	# in the MNI152 space template. This is due to the limitations of volume-based
	# registration. So, to avoid a lack of coverage in a group analysis around the
	# penumbra of cortex, we will add a single dilation step to the input prior to
	# creating the Level1 maps.
	#
	# Ideally, we would condition this dilation on the resolution of the fMRI 
	# data.  Empirically, a single round of dilation gives very good group 
	# coverage of MNI brain for the 2 mm resolution of HCP fMRI data. So a single
	# dilation is what we use below.
	#
	# Note that for many subjects, this dilation will result in signal extending
	# BEYOND the limits of brain in the MNI152 template.  However, that is easily
	# fixed by masking with the MNI space brain template mask if so desired.
	#
	# The specific implementation involves:
	# a) Edge-constrained spatial smoothing on the input fMRI time series (and masking
	#    that back to the original mask).  This step was completed above.
	# b) Spatial dilation of the input fMRI time series, followed by edge constrained smoothing
	# c) Adding the voxels from (b) that are NOT part of (a) into (a).
	#
	# The motivation for this implementation is that:
	# 1) Identical voxel-wise results are obtained within the original mask.  So, users
	#    that desire the original ("tight") FreeSurfer-defined brain mask (which is
	#    implicitly represented as the non-zero voxels in the InputSBRef volume) can
	#    mask back to that if they chose, with NO impact on the voxel-wise results.
	# 2) A simpler possible approach of just dilating the result of step (a) results in 
	#    an unnatural pattern of dark/light/dark intensities at the edge of brain,
	#    whereas the combination of steps (b) and (c) yields a more natural looking 
	#    transition of intensities in the added voxels.
	echo "MAIN: SMOOTH_OR_PARCELLATE: SMOOTH_NIFTI: Add volume dilation"

	# Dilate the original BOLD time series, then do (edge-constrained) smoothing
	fslmaths ${FEATDir}/mask_orig -dilM -bin ${FEATDir}/mask_dilM
	fslmaths ${FEATDir}/mask_dilM \
	  -kernel gauss ${FinalSmoothingSigma} -fmean ${FEATDir}/mask_dilM_weight -odt float
	fslmaths ${InputfMRI} -dilM -kernel gauss ${FinalSmoothingSigma} -fmean \
	  -div ${FEATDir}/mask_dilM_weight -mas ${FEATDir}/mask_dilM \
	  ${FEATDir}/${LevelOnefMRIName}_dilM${FinalSmoothingString} -odt float

	# Take just the additional "rim" voxels from the dilated then smoothed time series, and add them
	# into the smoothed time series (that didn't have any dilation)
	SmoothedDilatedResultFile=${FEATDir}/${LevelOnefMRIName}${FinalSmoothingString}_dilMrim
	fslmaths ${FEATDir}/mask_orig -binv ${FEATDir}/mask_orig_inv
	fslmaths ${FEATDir}/${LevelOnefMRIName}_dilM${FinalSmoothingString} \
	  -mas ${FEATDir}/mask_orig_inv \
	  -add ${FEATDir}/${LevelOnefMRIName}${FinalSmoothingString} \
	  ${SmoothedDilatedResultFile}

fi # end Volume spatial smoothing



##### RUN film_gls (GLM ANALYSIS ON LEVEL 1) #####

# Run CIFTI Dense Grayordinates Analysis (if requested)
if $runDense ; then
	# Dense Grayordinates Processing
	echo "MAIN: RUN_GLM: Dense Grayordinates Analysis"
	#Split into surface and volume
	echo "MAIN: RUN_GLM: Split into surface and volume"
	${CARET7DIR}/wb_command -cifti-separate-all ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${RegString}${TemporalFilterString}${FinalSmoothingString}_clean.dtseries.nii -volume ${FEATDir}/${LevelOnefMRIName}_AtlasSubcortical${RegString}${TemporalFilterString}${FinalSmoothingString}_clean.nii.gz -left ${FEATDir}/${LevelOnefMRIName}${RegString}${TemporalFilterString}${FinalSmoothingString}_clean.atlasroi.L.${LowResMesh}k_fs_LR.func.gii -right ${FEATDir}/${LevelOnefMRIName}${RegString}${TemporalFilterString}${FinalSmoothingString}_clean.atlasroi.R.${LowResMesh}k_fs_LR.func.gii

	#Run film_gls on subcortical volume data
	echo "MAIN: RUN_GLM: Run film_gls on subcortical volume data"
	film_gls --rn=${FEATDir}/SubcorticalVolumeStats --sa --ms=5 --in=${FEATDir}/${LevelOnefMRIName}_AtlasSubcortical${RegString}${TemporalFilterString}${FinalSmoothingString}_clean.nii.gz --pd=${DesignMatrix} --con=${DesignContrasts} ${ExtraArgs} --thr=1 --mode=volumetric
	rm ${FEATDir}/${LevelOnefMRIName}_AtlasSubcortical${RegString}${TemporalFilterString}${FinalSmoothingString}_clean.nii.gz

	#Run film_gls on cortical surface data 
	echo "MAIN: RUN_GLM: Run film_gls on cortical surface data"
	for Hemisphere in L R ; do
		#Prepare for film_gls  
		echo "MAIN: RUN_GLM: Prepare for film_gls"
		${CARET7DIR}/wb_command -metric-dilate ${FEATDir}/${LevelOnefMRIName}${RegString}${TemporalFilterString}${FinalSmoothingString}_clean.atlasroi.${Hemisphere}.${LowResMesh}k_fs_LR.func.gii ${DownSampleFolder}/${Subject}.${Hemisphere}.midthickness.${LowResMesh}k_fs_LR.surf.gii 50 ${FEATDir}/${LevelOnefMRIName}${RegString}${TemporalFilterString}${FinalSmoothingString}_clean.atlasroi_dil.${Hemisphere}.${LowResMesh}k_fs_LR.func.gii -nearest

		#Run film_gls on surface data
		echo "MAIN: RUN_GLM: Run film_gls on surface data"
		film_gls --rn=${FEATDir}/${Hemisphere}_SurfaceStats --sa --ms=15 --epith=5 --in2=${DownSampleFolder}/${Subject}.${Hemisphere}.midthickness.${LowResMesh}k_fs_LR.surf.gii --in=${FEATDir}/${LevelOnefMRIName}${RegString}${TemporalFilterString}${FinalSmoothingString}_clean.atlasroi_dil.${Hemisphere}.${LowResMesh}k_fs_LR.func.gii --pd=${DesignMatrix} --con=${DesignContrasts} ${ExtraArgs} --mode=surface
		rm ${FEATDir}/${LevelOnefMRIName}${RegString}${TemporalFilterString}${FinalSmoothingString}_clean.atlasroi_dil.${Hemisphere}.${LowResMesh}k_fs_LR.func.gii ${FEATDir}/${LevelOnefMRIName}${RegString}${TemporalFilterString}${FinalSmoothingString}_clean.atlasroi.${Hemisphere}.${LowResMesh}k_fs_LR.func.gii	
	done

	# Merge Cortical Surface and Subcortical Volume into Grayordinates
	echo "MAIN: RUN_GLM: Merge Cortical Surface and Subcortical Volume into Grayordinates"
	mkdir ${FEATDir}/GrayordinatesStats
	cat ${FEATDir}/SubcorticalVolumeStats/dof > ${FEATDir}/GrayordinatesStats/dof
	cat ${FEATDir}/SubcorticalVolumeStats/logfile > ${FEATDir}/GrayordinatesStats/logfile
	cat ${FEATDir}/L_SurfaceStats/logfile >> ${FEATDir}/GrayordinatesStats/logfile
	cat ${FEATDir}/R_SurfaceStats/logfile >> ${FEATDir}/GrayordinatesStats/logfile

	for Subcortical in ${FEATDir}/SubcorticalVolumeStats/*nii.gz ; do
		File=$( basename $Subcortical .nii.gz );
		${CARET7DIR}/wb_command -cifti-create-dense-timeseries ${FEATDir}/GrayordinatesStats/${File}.dtseries.nii -volume $Subcortical $ROIsFolder/Atlas_ROIs.${GrayordinatesResolution}.nii.gz -left-metric ${FEATDir}/L_SurfaceStats/${File}.func.gii -roi-left ${DownSampleFolder}/${Subject}.L.atlasroi.${LowResMesh}k_fs_LR.shape.gii -right-metric ${FEATDir}/R_SurfaceStats/${File}.func.gii -roi-right ${DownSampleFolder}/${Subject}.R.atlasroi.${LowResMesh}k_fs_LR.shape.gii
	done
	rm -r ${FEATDir}/SubcorticalVolumeStats ${FEATDir}/L_SurfaceStats ${FEATDir}/R_SurfaceStats
fi

# Run CIFTI Parcellated Analysis (if requested)
if $runParcellated ; then
	# Parcellated Processing
	echo "MAIN: RUN_GLM: Parcellated Analysis"
	# Convert CIFTI to "fake" NIFTI
	${CARET7DIR}/wb_command -cifti-convert -to-nifti ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${RegString}${TemporalFilterString}${FinalSmoothingString}${ParcellationString}_clean.${Extension} ${FEATDir}/${LevelOnefMRIName}_Atlas${RegString}${TemporalFilterString}${FinalSmoothingString}${ParcellationString}_clean_FAKENIFTI.nii.gz
	# Now run film_gls on the fakeNIFTI file
	film_gls --rn=${FEATDir}/ParcellatedStats --in=${FEATDir}/${LevelOnefMRIName}_Atlas${RegString}${TemporalFilterString}${FinalSmoothingString}${ParcellationString}_clean_FAKENIFTI.nii.gz --pd=${DesignMatrix} --con=${DesignContrasts} ${ExtraArgs} --thr=1 --mode=volumetric
	# Remove "fake" NIFTI time series file
	rm ${FEATDir}/${LevelOnefMRIName}_Atlas${RegString}${TemporalFilterString}${FinalSmoothingString}${ParcellationString}_clean_FAKENIFTI.nii.gz
	# Convert "fake" NIFTI output files (copes, varcopes, zstats) back to CIFTI
	templateCIFTI=${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${RegString}${TemporalFilterString}${FinalSmoothingString}${ParcellationString}_clean.ptseries.nii
	for fakeNIFTI in `ls ${FEATDir}/ParcellatedStats/*.nii.gz` ; do
		CIFTI=$( echo $fakeNIFTI | sed -e "s|.nii.gz|.${Extension}|" );
		${CARET7DIR}/wb_command -cifti-convert -from-nifti $fakeNIFTI $templateCIFTI $CIFTI -reset-timepoints 1 1
		rm $fakeNIFTI;
	done
fi

# Standard NIFTI Volume-based Processsing###
if $runVolume ; then
	echo "MAIN: RUN_GLM: Standard NIFTI Volume Analysis"
	echo "MAIN: RUN_GLM: Run film_gls on volume data"
	film_gls --rn=${FEATDir}/StandardVolumeStats --sa --ms=5 --in=${FEATDir}/${LevelOnefMRIName}${TemporalFilterString}${FinalSmoothingString}.nii.gz --pd=${DesignMatrix} --con=${DesignContrasts} ${ExtraArgs} --thr=1000

	# Cleanup
	rm -f ${FEATDir}/mask_*.nii.gz
	rm -f ${FEATDir}/${LevelOnefMRIName}${FinalSmoothingString}.nii.gz
	rm -f ${FEATDir}/${LevelOnefMRIName}_dilM${FinalSmoothingString}.nii.gz
	rm -f ${SmoothedDilatedResultFile}*.nii.gz
fi

echo "MAIN: Complete"
