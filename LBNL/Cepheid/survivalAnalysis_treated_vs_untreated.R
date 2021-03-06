library(survival)
library(ROCR)

#Start with case predictions
datadir="/Users/obigriffith/Dropbox/LBNL/Projects/Cepheid/analyzing/analysis_final2/RandomForests/test_survival/17gene_optimized/"

setwd(datadir)
case_pred_outfile="Cepheid_CasePredictions.txt"
KMplotfile_treated="Survival_not_downsampled_RFRS_treated.pdf"
KMplotfile_untreated="Survival_not_downsampled_RFRS_untreated.pdf"
ROC_pdffile_treated="Cepheid_ROC_treated.pdf"
ROC_pdffile_untreated="Cepheid_ROC_untreated.pdf"

#read RF results and clinical data from file
clindata_plusRF=read.table(case_pred_outfile, header = TRUE, na.strings = "NA", sep="\t")

#Add column of 10yr censored data
clindata_plusRF[,"e_rfs_10yrcens"]=clindata_plusRF[,"e_rfs"]
clindata_plusRF[which(clindata_plusRF[,"t_rfs"]>10),"e_rfs_10yrcens"]=0

#Create ROC curve plot and calculate AUC
#Use RF relapse scores as predictive variable
#The ROC curve will be generated by stepping up through different thresholds for calling recurrence vs non-recurrence

#First reduce to just patients with 10yr relapse which are also treated OR untreated
cases_treated = which(!is.na(clindata_plusRF[,"X10yr_relapse"]) & clindata_plusRF[,"treatment"]!="none")
cases_untreated = which(!is.na(clindata_plusRF[,"X10yr_relapse"]) & clindata_plusRF[,"treatment"]=="none")

#Calculate ROC AUC and plot for treated
target_treated=clindata_plusRF[cases_treated,"X10yr_relapse"]
predictions_treated=as.vector(clindata_plusRF[cases_treated,"Relapse"])
pred_treated=prediction(predictions_treated,target_treated)
#First calculate the AUC value
perf_AUC_treated=performance(pred_treated,"auc")
AUC_treated=perf_AUC_treated@y.values[[1]]
AUC_out_treated=paste("AUC=",AUC_treated,sep="")
#Then, plot the actual ROC curve
perf_ROC_treated=performance(pred_treated,"tpr","fpr")
pdf(file=ROC_pdffile_treated)
plot(perf_ROC_treated, main="ROC plot")
text(0.5,0.5,paste("AUC = ",format(AUC_treated, digits=5, scientific=FALSE)))
dev.off()

#Calculate ROC AUC and plot for untreated
target_untreated=clindata_plusRF[cases_untreated,"X10yr_relapse"]
predictions_untreated=as.vector(clindata_plusRF[cases_untreated,"Relapse"])
pred_untreated=prediction(predictions_untreated,target_untreated)
#First calculate the AUC value
perf_AUC_untreated=performance(pred_untreated,"auc")
AUC_untreated=perf_AUC_untreated@y.values[[1]]
AUC_out_untreated=paste("AUC=",AUC_untreated,sep="")
#Then, plot the actual ROC curve
perf_ROC_untreated=performance(pred_untreated,"tpr","fpr")
pdf(file=ROC_pdffile_untreated)
plot(perf_ROC_untreated, main="ROC plot")
text(0.5,0.5,paste("AUC = ",format(AUC_untreated, digits=5, scientific=FALSE)))
dev.off()

#TREATED
#Perform survival analysis for treated patient cohort without down-sampling
#Create survival plot and statistics
#Calculate logrank survival statistic between groups
#Create new dataframe with just necessary data
surv_data_treated=clindata_plusRF[cases_treated,c("t_rfs","e_rfs_10yrcens","RF_risk_group")]

#create a survival object using data
surv_data_treated.surv = with(surv_data_treated, Surv(t_rfs, e_rfs_10yrcens==1))
#Calculate p-value
survdifftest_treated=survdiff(surv_data_treated.surv ~ RF_risk_group, data = surv_data_treated)
survpvalue_treated = 1 - pchisq(survdifftest_treated$chisq, length(survdifftest_treated$n) - 1)
survpvalue_treated = format(as.numeric(survpvalue_treated), digits=3)

#Linear test p-value 
#Using the "Score (logrank) test" pvalue from coxph with riskgroup coded as ordinal variable
#See http://r.789695.n4.nabble.com/Trend-test-for-survival-data-td857144.html
#recode  risk groups as 1,2,3
surv_data_lin_treated=clindata_plusRF[cases_treated,c("t_rfs","e_rfs_10yrcens","RF_risk_group")]
surv_data_lin_treated[,"RF_risk_group"]=as.vector(surv_data_lin_treated[,"RF_risk_group"])
surv_data_lin_treated[which(surv_data_lin_treated[,"RF_risk_group"]=="low"),"RF_risk_group"]=1
surv_data_lin_treated[which(surv_data_lin_treated[,"RF_risk_group"]=="int"),"RF_risk_group"]=2
surv_data_lin_treated[which(surv_data_lin_treated[,"RF_risk_group"]=="high"),"RF_risk_group"]=3
surv_data_lin_treated[,"RF_risk_group"]=as.numeric(surv_data_lin_treated[,"RF_risk_group"])
survpvalue_linear_treated=summary(coxph(Surv(t_rfs, e_rfs_10yrcens)~RF_risk_group, data=surv_data_lin_treated))$sctest[3]
survpvalue_linear_treated = format(as.numeric(survpvalue_linear_treated), digits=3)

##Plot KM curve treated
krfit.by_RFgroup_treated = survfit(surv_data_treated.surv ~ RF_risk_group, data = surv_data_treated)
pdf(file=KMplotfile_treated)
colors = rainbow(5)
title="Survival by RFRS - Not downsampled, Treated"
plot(krfit.by_RFgroup_treated, col = colors, xlab = "Time (years)", ylab = "Relapse Free Survival", main=title, cex.axis=1.3, cex.lab=1.4)
abline(v = 10, col = "black", lty = 3)
#Set order of categories, categories are by default assigned colors alphabetically by survfit
groups=sort(unique(surv_data_treated[,"RF_risk_group"])) #returns unique factor levels sorted alphabetically
names(colors)=groups
groups_custom=c("low","int","high")
colors_custom=colors[groups_custom]
group_sizes_custom=table(surv_data_treated[,"RF_risk_group"])[groups_custom]
groups_custom=c("Low","Int","High") #Reset names for consistency with manuscript
legend_text=c(paste(groups_custom, " ", "(", group_sizes_custom, ")", sep=""),paste("p =", survpvalue_linear_treated, sep=" "))
legend(x = "bottomleft", legend = legend_text, col = c(colors_custom,"white"), lty = "solid", bty="n", cex=1.2)
dev.off()



#UNTREATED
#Perform survival analysis for untreated patient cohort without down-sampling
#Create survival plot and statistics
#Calculate logrank survival statistic between groups
#Create new dataframe with just necessary data
surv_data_untreated=clindata_plusRF[cases_untreated,c("t_rfs","e_rfs_10yrcens","RF_risk_group")]

#create a survival object using data
surv_data_untreated.surv = with(surv_data_untreated, Surv(t_rfs, e_rfs_10yrcens==1))
#Calculate p-value
survdifftest_untreated=survdiff(surv_data_untreated.surv ~ RF_risk_group, data = surv_data_untreated)
survpvalue_untreated = 1 - pchisq(survdifftest_untreated$chisq, length(survdifftest_untreated$n) - 1)
survpvalue_untreated = format(as.numeric(survpvalue_untreated), digits=3)

#Linear test p-value 
#Using the "Score (logrank) test" pvalue from coxph with riskgroup coded as ordinal variable
#See http://r.789695.n4.nabble.com/Trend-test-for-survival-data-td857144.html
#recode  risk groups as 1,2,3
surv_data_lin_untreated=clindata_plusRF[cases_untreated,c("t_rfs","e_rfs_10yrcens","RF_risk_group")]
surv_data_lin_untreated[,"RF_risk_group"]=as.vector(surv_data_lin_untreated[,"RF_risk_group"])
surv_data_lin_untreated[which(surv_data_lin_untreated[,"RF_risk_group"]=="low"),"RF_risk_group"]=1
surv_data_lin_untreated[which(surv_data_lin_untreated[,"RF_risk_group"]=="int"),"RF_risk_group"]=2
surv_data_lin_untreated[which(surv_data_lin_untreated[,"RF_risk_group"]=="high"),"RF_risk_group"]=3
surv_data_lin_untreated[,"RF_risk_group"]=as.numeric(surv_data_lin_untreated[,"RF_risk_group"])
survpvalue_linear_untreated=summary(coxph(Surv(t_rfs, e_rfs_10yrcens)~RF_risk_group, data=surv_data_lin_untreated))$sctest[3]
survpvalue_linear_untreated = format(as.numeric(survpvalue_linear_untreated), digits=3)

##Plot KM curve untreated
krfit.by_RFgroup_untreated = survfit(surv_data_untreated.surv ~ RF_risk_group, data = surv_data_untreated)
pdf(file=KMplotfile_untreated)
colors = rainbow(5)
title="Survival by RFRS - Not downsampled, Untreated"
plot(krfit.by_RFgroup_untreated, col = colors, xlab = "Time (years)", ylab = "Relapse Free Survival", main=title, cex.axis=1.3, cex.lab=1.4)
abline(v = 10, col = "black", lty = 3)
#Set order of categories, categories are by default assigned colors alphabetically by survfit
groups=sort(unique(surv_data_untreated[,"RF_risk_group"])) #returns unique factor levels sorted alphabetically
names(colors)=groups
groups_custom=c("low","int","high")
colors_custom=colors[groups_custom]
group_sizes_custom=table(surv_data_untreated[,"RF_risk_group"])[groups_custom]
groups_custom=c("Low","Int","High") #Reset names for consistency with manuscript
legend_text=c(paste(groups_custom, " ", "(", group_sizes_custom, ")", sep=""),paste("p =", survpvalue_linear_untreated, sep=" "))
legend(x = "bottomleft", legend = legend_text, col = c(colors_custom,"white"), lty = "solid", bty="n", cex=1.2)
dev.off()

