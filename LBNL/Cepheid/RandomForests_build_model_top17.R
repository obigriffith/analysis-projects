library(randomForest)
library(ROCR)
require(Hmisc)
library(genefilter)
library(mclust)
library(heatmap.plus)
library(fBasics)

#Set working directory and filenames for Input/output
setwd("C:/Users/Obi/Documents/My Dropbox/Projects/Cepheid/analyzing/analysis_final2/RandomForests/train_survival/unbalanced/final_100k_trees/finaltop17/")

datafile="C:/Users/Obi/Documents/My Dropbox/Projects/Cepheid/processing/processed_final2/train_survival/combined/ALL_gcrma.txt" #combined (standardCDF + customCDF)
clindatafile="C:/Users/Obi/Documents/My Dropbox/Projects/Cepheid/clinical_data/filtered_combined_data_anno.final.train.2.txt"

outfile="Cepheid_RFoutput.txt"
outfile_top17="Cepheid_RFoutput_top17.txt"
case_pred_outfile="Cepheid_CasePredictions.txt"
varimp_pdffile="Cepheid_varImps.pdf"
MDS_pdffile="Cepheid_MDS.pdf"
case_margins_file="Cepheid_Margins.pdf"
ROC_pdffile="Cepheid_ROC.pdf"
vote_dist_pdffile="Cepheid_vote_dist.pdf"
vote_density_pdffile="density_RF.pdf"
margins_mixed_model_clustering_pdffile="Margins_MM.pdf"

new_case_pred_outfile="Cepheid_NewCasePredictions.txt"
combined_case_pred_outfile="Cepheid_CasePredictions_combined.txt"
combined_case_pred_downsamp_outfile="Cepheid_CasePredictions_combined_downsamp.txt"
combined_case_pred_1000downsamp_10yrRFS_outfile="Cepheid_CasePredictions_combined_100downsamp_10yrRFS.txt"

#Read in data (expecting a tab-delimited file with header line and rownames)
data_import=read.table(datafile, header = TRUE, na.strings = "NA", sep="\t")
clin_data_import=read.table(clindatafile, header = TRUE, na.strings = "NA", sep="\t")

#NEED TO GET CLINICAL DATA IN SAME ORDER AS GCRMA DATA
clin_data_order=order(clin_data_import[,"GSM"])
clindata=clin_data_import[clin_data_order,]
data_order=order(colnames(data_import)[4:length(colnames(data_import))])+3 #Order data without first three columns, then add 3 to get correct index in original file
rawdata=data_import[,c(1:3,data_order)] #grab first three columns, and then remaining columns in order determined above

header=colnames(rawdata)

#Get pre-selected optimized top 20/25 predictor variables
top17opt_probes=c("204767_s_at","10682_at","201291_s_at","9133_at","1164_at","208079_s_at","23224_at","55435_at","23220_at","201461_s_at","202709_at","57122_at","23405_at","201483_s_at","29127_at","204416_x_at","10628_at")
top17opt_data=rawdata[rawdata[,1]%in%top17opt_probes,]

predictor_data=t(top17opt_data[,4:length(header)]) #Top17 optimized list
predictor_names=top17opt_data[,3] #gene symbol

colnames(predictor_data)=predictor_names

#Filter down to just cases which have 10yr FU (i.e., exclude NAs)
cases_10yr = !is.na(clindata[,"X10yr_relapse"])
clindata_10yr=clindata[cases_10yr,]
predictor_data_10yr=predictor_data[cases_10yr,]

#Also put aside cases without 10yr FU
cases_no10yr = is.na(clindata[,"X10yr_relapse"])
clindata_no10yr=clindata[cases_no10yr,]
predictor_data_no10yr=predictor_data[cases_no10yr,]

#Get target variable and specify as factor/categorical
target=clindata_10yr[,"X10yr_relapse"] #recurrences after 10yrs not considered events
#target=clindata_10yr[,"e_rfs"] #All recurrences (even after 10yrs) considered events
target[target==0]="NoRelapse"
target[target==1]="Relapse"
target=as.factor(target)

#Run RandomForests
#NOTE: use an ODD number for ntree. When the forest/ensembl is used on test data, ties are broken randomly.
#Having an odd number of trees avoids this issue and makes the model fully deterministic
#rf_model=randomForest(x=predictor_data_10yr, y=target, importance = TRUE, ntree = 10001, proximity=TRUE)

#Optional: use down-sampling to attempt to compensate for unequal class-sizes
#tmp = as.vector(table(target))
#num_classes = length(tmp)
#min_size = tmp[order(tmp,decreasing=FALSE)[1]]
#sampsizes = rep(min_size,num_classes)
#rf_model=randomForest(x=predictor_data_10yr, y=target, importance = TRUE, ntree = 50001, proximity=TRUE, sampsize=sampsizes) 
#rf_model=randomForest(x=predictor_data_10yr, y=target, importance = TRUE, ntree = 10001, proximity=TRUE, sampsize=sampsizes) 

#No downsampling
rf_model=randomForest(x=predictor_data_10yr, y=target, importance = TRUE, ntree = 10001, proximity=TRUE)

#######################################
#Save RF classifier with save()
save(rf_model, file="RF_model_17gene_optimized")

#Get importance measures
rf_importances=importance(rf_model, scale=FALSE)

#Determine performance statistics
confusion=rf_model$confusion
sensitivity=(confusion[2,2]/(confusion[2,2]+confusion[2,1]))*100
specificity=(confusion[1,1]/(confusion[1,1]+confusion[1,2]))*100
overall_error=rf_model$err.rate[length(rf_model$err.rate[,1]),1]*100
overall_accuracy=1-overall_error
class1_error=paste(rownames(confusion)[1]," error rate= ",confusion[1,3], sep="")
class2_error=paste(rownames(confusion)[2]," error rate= ",confusion[2,3], sep="")
overall_accuracy=100-overall_error

#Prepare stats for output to file
sens_out=paste("sensitivity=",sensitivity, sep="")
spec_out=paste("specificity=",specificity, sep="")
err_out=paste("overall error rate=",overall_error,sep="")
acc_out=paste("overall accuracy=",overall_accuracy,sep="")
misclass_1=paste(confusion[1,2], rownames(confusion)[1],"misclassified as", colnames(confusion)[2], sep=" ")
misclass_2=paste(confusion[2,1], rownames(confusion)[2],"misclassified as", colnames(confusion)[1], sep=" ")

#Prepare confusion table for writing to file
confusion_out=confusion[1:2,1:2]
confusion_out=cbind(rownames(confusion_out), confusion_out)

#Produce graph of variable importances for top 30 markers
pdf(file=varimp_pdffile)
varImpPlot(rf_model, type=2, n.var=30, scale=FALSE, main="Variable Importance (Gini) for top 20 predictors")
dev.off()

#Produce MDS plot
pdf(file=MDS_pdffile)
target_labels=as.vector(target)
target_labels[target_labels=="NoRelapse"]="N"
target_labels[target_labels=="Relapse"]="R"
MDSplot(rf_model, target, k=2, xlab="", ylab="", pch=target_labels, palette=c("red", "blue"), main="MDS plot")
dev.off()

#Determine which cases were misclassified based on OOB testing and by how much
#Margins represent the fraction of votes for the correct class minus the fraction for the incorrect class
#If class is determined by majority rules, then cases with positive margins are correct and vice versa
margins=margin(rf_model, target)
#combine the patient ids with target/known class, predicted class, votes, and margins
case_predictions=cbind(clindata_10yr[,c(1,3,4,16,17,19)],target,rf_model$predicted,rf_model$votes,as.vector(margins))
misclass_cases=case_predictions[case_predictions[,"target"]!=case_predictions[,"rf_model$predicted"],]

#Write case predictions to file
write.table(case_predictions,file=case_pred_outfile, sep="\t", quote=FALSE, col.names=TRUE, row.names=FALSE)

#Produce graph of margins for all cases
#Note, when plot is called on a 'margin' object, it uses brewer.pal for color selection.
pdf(file=case_margins_file)
plot(margins, ylab="margins (fraction votes true - fraction votes false)", xlab="patient cases", main="Margins plot")
legend("bottomright", legend=c("NoRelapse","Relapse"), pch=c(20,20), col=c(brewer.pal(3,"Set1")[1], brewer.pal(3,"Set1")[2]))
dev.off()

#Attempt to define cutoffs by mixed-model clustering of votes/probabilities
#Force mclust to break into 3 clusters 
x=as.numeric(case_predictions[,"Relapse"])
mclust_margins=Mclust(x, G=3)
summary(mclust_margins, x) #Gives you list of values returned
classification_margins=mclust_margins$classification
num_clusters=mclust_margins$G

pdf(file=margins_mixed_model_clustering_pdffile)
par(mfrow=c(3,1), oma=c(2,2,2,2))
hist(x[classification_margins==1], xlim=c(0,1), col="blue", xlab="Log2 GCRMA value", main="component 1")
hist(x[classification_margins==2], xlim=c(0,1), col="red", xlab="Log2 GCRMA value", main="component 2")
hist(x[classification_margins==3], xlim=c(0,1), col="green", xlab="Log2 GCRMA value", main="component 3")
title(main="Separation of relapse probabilities by model-based clustering", outer=TRUE)
dev.off()

#Choose cutoffs - use max and min of "middle" cluster (#2) to break into three components
mm_cutoff1=min(x[classification_margins==2])
mm_cutoff2=max(x[classification_margins==2])
mm_cutoff1_out=paste("Mixed Model cutoff 1=",mm_cutoff1,sep="")
mm_cutoff2_out=paste("Mixed Model cutoff 2=",mm_cutoff2,sep="")

#Produce back-to-back histogram of vote distributions for Relapse and NoRelapse
options(digits=2) 
pdf(file=vote_dist_pdffile)
out <- histbackback(split(rf_model$votes[,"Relapse"], target), probability=FALSE, xlim=c(-50,50), main = 'Vote distributions for patients classified by RF', axes=TRUE, ylab="Fraction votes (Relapse)")
#add color
barplot(-out$left, col="red" , horiz=TRUE, space=0, add=TRUE, axes=FALSE) 
barplot(out$right, col="blue", horiz=TRUE, space=0, add=TRUE, axes=FALSE) 
dev.off()

#Create ROC curve plot and calculate AUC
#Can use Malignant vote fractions or Malignant-Benign vote fractions as predictive variable
#The ROC curve will be generated by stepping up through different thresholds for calling malignant vs benign
predictions=as.vector(rf_model$votes[,2])
pred=prediction(predictions,target)
#First calculate the AUC value
perf_AUC=performance(pred,"auc")
AUC=perf_AUC@y.values[[1]]
AUC_out=paste("AUC=",AUC,sep="")
#Then, plot the actual ROC curve
perf_ROC=performance(pred,"tpr","fpr")
pdf(file=ROC_pdffile)
plot(perf_ROC, main="ROC plot")
text(0.5,0.5,paste("AUC = ",format(AUC, digits=5, scientific=FALSE)))
dev.off()

#Plot density of RF scores for two classes - allows comparison to Francois' Oncotype results
dx=case_predictions[,"Relapse"]
classes=case_predictions[,"X10yr_relapse"]
pdf(file=vote_density_pdffile)
plot(density(dx[classes==0],na.rm=T),main='Density of RF scores by 10 year relapse');lines(density(dx[classes==1],na.rm=T),col='red');legend('topright',legend=c('nonrecurrent','recurrent'),col=c('black','red'),pch=20)
dev.off()

#Print results to file
write.table(rf_importances[,4],file=outfile, sep="\t", quote=FALSE, col.names=FALSE)
write("confusion table", file=outfile, append=TRUE)
write.table(confusion_out,file=outfile, sep="\t", quote=FALSE, col.names=TRUE, row.names=FALSE, append=TRUE)
write(c(sens_out,spec_out,acc_out,err_out,class1_error,class2_error,misclass_1,misclass_2,AUC_out,mm_cutoff1_out,mm_cutoff2_out), file=outfile, append=TRUE)

#Try running data through forest
RF_predictions_responses=predict(rf_model, predictor_data_no10yr, type="response")
RF_predictions_probs=predict(rf_model, predictor_data_no10yr, type="prob")
RF_predictions_votes=predict(rf_model, predictor_data_no10yr, type="vote")

#Write new case predictions to file
new_case_predictions=cbind(clindata_no10yr[,c(1,3,4,16,17,19)],RF_predictions_responses,RF_predictions_probs)
write.table(new_case_predictions,file=new_case_pred_outfile, sep="\t", quote=FALSE, col.names=TRUE, row.names=FALSE)

#Combine all case predictions into a single file. Only combine shared columns
case_predictions_for_combine=case_predictions[,c("Study","GSE","GSM","t_rfs","e_rfs","X10yr_relapse","rf_model$predicted","NoRelapse","Relapse")]
colnames(case_predictions_for_combine)=c("Study","GSE","GSM","t_rfs","e_rfs","X10yr_relapse","RF_predictions_responses","NoRelapse","Relapse")
case_predictions_all_combined=rbind(case_predictions_for_combine,new_case_predictions)
write.table(case_predictions_all_combined,file=combined_case_pred_outfile, sep="\t", quote=FALSE, col.names=TRUE, row.names=FALSE)


#Define risk groups
#risk group 1: Based on cutoffs chosen by mixed-model clustering of margins
case_predictions_all_combined[case_predictions_all_combined[,"Relapse"] <= mm_cutoff1,"RF_group1"]="low"
case_predictions_all_combined[case_predictions_all_combined[,"Relapse"] > mm_cutoff1 & case_predictions_all_combined[,"Relapse"] < mm_cutoff2,"RF_group1"]="int"
case_predictions_all_combined[case_predictions_all_combined[,"Relapse"] >= mm_cutoff2,"RF_group1"]="high"

#Down-sample relapses to create dataset more comparable to Oncotype publication (i.e., 15% overall relapse rate)
#Keep all NoRelapses
NoRelapseCases=which(is.na(case_predictions_all_combined[,"X10yr_relapse"]) | case_predictions_all_combined[,"X10yr_relapse"]==0)
RelapseCases=which(case_predictions_all_combined[,"X10yr_relapse"]==1)

#Downsample Relapse cases so that they represent only 15% of total cases:  x / (429+x) = 0.15 [solving for x, ~76]
#Do multiple downsampling and get N and 10yr relapse rates for each risk group (RF_group1), then average
I=1000
downsampledata=matrix(data=NA, nrow=I, ncol=6)
for (i in 1:I){
 random_RelapseCases=sample(x=RelapseCases, size=76, replace = FALSE, prob = NULL)
 case_predictions_all_combined_down=case_predictions_all_combined[c(NoRelapseCases,random_RelapseCases),]
 low_10yr_relapses=case_predictions_all_combined_down[case_predictions_all_combined_down[,"RF_group1"]=="low","X10yr_relapse"]
 int_10yr_relapses=case_predictions_all_combined_down[case_predictions_all_combined_down[,"RF_group1"]=="int","X10yr_relapse"]
 high_10yr_relapses=case_predictions_all_combined_down[case_predictions_all_combined_down[,"RF_group1"]=="high","X10yr_relapse"]
 perc_10yr_relapse_low=sum(low_10yr_relapses, na.rm=TRUE)/length(low_10yr_relapses)*100
 perc_10yr_relapse_int=sum(int_10yr_relapses, na.rm=TRUE)/length(int_10yr_relapses)*100
 perc_10yr_relapse_high=sum(high_10yr_relapses, na.rm=TRUE)/length(high_10yr_relapses)*100
 downsampledata[i,1:6]=c(perc_10yr_relapse_low,length(low_10yr_relapses),perc_10yr_relapse_int,length(int_10yr_relapses),perc_10yr_relapse_high,length(high_10yr_relapses))
}
colnames(downsampledata)=c("low_perc","low_N","int_perc","int_N","high_perc","high_N")
#Print means to screen
mean(downsampledata[,"low_perc"]);mean(downsampledata[,"int_perc"]);mean(downsampledata[,"high_perc"])
write.table(downsampledata,file=combined_case_pred_1000downsamp_10yrRFS_outfile, sep="\t", quote=FALSE, col.names=TRUE, row.names=FALSE)

#Create representative result for plotting survival figure: run the block below until %'s similar to means above
random_RelapseCases=sample(x=RelapseCases, size=76, replace = FALSE, prob = NULL)
case_predictions_all_combined_down=case_predictions_all_combined[c(NoRelapseCases,random_RelapseCases),]
low_10yr_relapses=case_predictions_all_combined_down[case_predictions_all_combined_down[,"RF_group1"]=="low","X10yr_relapse"]
int_10yr_relapses=case_predictions_all_combined_down[case_predictions_all_combined_down[,"RF_group1"]=="int","X10yr_relapse"]
high_10yr_relapses=case_predictions_all_combined_down[case_predictions_all_combined_down[,"RF_group1"]=="high","X10yr_relapse"]
perc_10yr_relapse_low=sum(low_10yr_relapses, na.rm=TRUE)/length(low_10yr_relapses)*100
perc_10yr_relapse_int=sum(int_10yr_relapses, na.rm=TRUE)/length(int_10yr_relapses)*100
perc_10yr_relapse_high=sum(high_10yr_relapses, na.rm=TRUE)/length(high_10yr_relapses)*100
perc_10yr_relapse_low; perc_10yr_relapse_int; perc_10yr_relapse_high #Check values against means for above
write.table(case_predictions_all_combined_down,file=combined_case_pred_downsamp_outfile, sep="\t", quote=FALSE, col.names=TRUE, row.names=FALSE)
