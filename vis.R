#!/usr/bin/env Rscript
# -*- coding: utf-8 -*-

library(tools)
library(ggplot2)
library(ggsci)
library(tikzDevice)
library(reshape2)
library(optparse)

plot_token_dist_UNSC <- function(){
  # read data to dataframe
  stats <- read.csv("./data/UNSC/pred/stats_tokens.csv",
                    stringsAsFactors=FALSE)
  # bin token counts to get new aggregate by length
  stats$bin <- cut(stats$len,seq(0,max(stats$len)+100,100),dig.lab=5)
  names(stats)[3] <- "bin"
  agg <- aggregate(stats$len,by=list(stats$bin),FUN=sum)
  names(agg) <- c("bin","len")
  # fill in remaining factor levels where no data is present
  agg[,2] <- as.numeric(agg[,2])
  agg$type = "Unfiltered"
  # make new combined plot with bin lengths
  count <- aggregate(stats$len,by=list(stats$bin),FUN=length)
  count <- as.numeric(count[,2])
  agg <- cbind(agg,count)
  names(agg)[4] <- "Number of Speeches [S]"
  names(agg)[2] <- "Token Count [T]"
  agg <- melt(agg,measure.vars = c(2,4))
  sums <- aggregate(agg[,4],by=list(agg$variable),FUN=sum)
  tikz("token_dist_UNSC_length.tex", width=20, height=15, standAlone = TRUE)
  # make ggplot object
  g <- ggplot(agg,aes(x=bin,y=value,fill=variable)) +
    geom_bar(stat="identity", color = "black", size = 0.5)+
    geom_text(aes(x, y, label=lab),
              data=data.frame(x=Inf, y=Inf, lab=c(paste0("$\\Sigma$ [T] = ",formatC(sums[1,2], format = "e", digits = 2)),paste0("$\\Sigma$ [S] = ",prettyNum(sums[2,2],big.mark=","))),
                              variable=unique(agg[,c("variable")])),
              hjust=1.1,vjust=1.8,size=10) +
    ylab("")+
    xlab("\nBinned Speech Length [Tokens]") +
    theme_bw() +
    theme(text = element_text(size=30),
          axis.text.x = element_text(angle = 90, hjust = 1, size = 18),
          legend.text = element_text(size=25),
          legend.title = element_text(size=25,face = "bold"),
          legend.key = element_rect(colour = "lightgray", fill = "white"),
          legend.position = "none",
          plot.title = element_text(hjust=0.5),
          strip.text.x = element_text(size = 27),
          strip.text.y = element_text(size = 27)) +
    scale_fill_npg() +
    facet_wrap(variable~.,nrow=2,scales="free_y")
  # process
  print(g)
  dev.off()
  texi2pdf("token_dist_UNSC_length.tex",clean=TRUE)
  file.remove("token_dist_UNSC_length.tex")
  file.rename("token_dist_UNSC_length.pdf",
              "./img/token_dist_UNSC_length.pdf")
  # aggregate with filtered counts
  stats$type <- "Unfiltered"
  if(file.exists("./data/UNSC/pred/pred_tokens_stats_512.csv")){
    path <- "./data/UNSC/pred/pred_tokens_stats_512.csv"
    to_add <- read.csv(path,stringsAsFactors=FALSE)
    to_add$len <- rowSums(to_add[,c(2:4)])
    to_add$bin <- cut(to_add$len,seq(0,max(to_add$len)+100,100),dig.lab=5)
    to_add <- to_add[,c("speech","len","bin")]
    names(to_add)[1] <- "id"
    to_add$type <- "Filtered_512"
  } else{
    to_add <- stats
    to_add[which(to_add[,2] > 512),2] = 0
    to_add$type <- "Filtered_512"
  }
  stats <- rbind(stats,to_add)
  agg <- aggregate(stats$len,by=list(stats$bin,stats$type),FUN=sum)
  agg_add <- aggregate(stats$len,by=list(stats$bin,stats$type),FUN=function(x) length(which(x!=0)))
  names(agg)[1] <- "bin"
  names(agg)[2] <- "type"
  names(agg)[3] <- "Token Count [T]"
  agg <- cbind(agg,agg_add[,3])
  names(agg)[4] <- "Number of Speeches [S]"
  agg[,2] <- factor(agg[,2],levels=c("Unfiltered","Filtered_512"))
  levels(agg$type) <- c("Full UNSC Corpus","Pruned UNSC Corpus [Sequence Length $\\leq$ 512]")
  agg[,3] <- as.numeric(agg[,3])
  agg[,4] <- as.numeric(agg[,4])
  agg <- melt(agg)
  sums <- aggregate(agg[,4],by=list(agg$variable,agg$type),FUN=sum)
  # create file
  tikz("token_dist_UNSC_length_combined.tex", width=20, height=15, standAlone = TRUE)
  # make ggplot object
  g <- ggplot(agg,aes(x=bin,y=value,fill=variable)) +
    geom_bar(stat="identity", color="black", size = 0.5)+
    geom_text(aes(x, y, label=lab),
              data=data.frame(x=Inf, y=Inf, lab=c(paste0("$\\Sigma$ [T] = ",formatC(sums[1,3], format = "e", digits = 2)),paste0("$\\Sigma$ [S] = ",prettyNum(sums[2,3],big.mark=",")),paste0("$\\Sigma$ [T] = ",formatC(sums[3,3], format = "e", digits = 2)),paste0("$\\Sigma$ [S] = ",prettyNum(sums[4,3],big.mark=","))),
                              type=sums[,2],variable=sums[,1]),
              hjust=1.1,vjust=1.8,size=10) +
    xlab("\nBinned Speech Length [Tokens]")+
    ylab("") +
    theme_bw() +
    theme(text = element_text(size=30),
          axis.text.x = element_text(angle = 90, hjust = 1, size = 10),
          legend.text = element_text(size=25),
          legend.title = element_text(size=25,face = "bold"),
          legend.key = element_rect(colour = "lightgray", fill = "white"),
          plot.title = element_text(hjust=0.5),
          legend.position = "none",
          strip.text.x = element_text(size = 27),
          strip.text.y = element_text(size = 27)) +
    scale_fill_npg() +
    ## ggtitle("Token Type Distribution by Speech Length") +
    facet_grid(variable~type,scales="free_y")
  # process
  print(g)
  dev.off()
  texi2pdf("token_dist_UNSC_length_combined.tex",clean=TRUE)
  file.remove("token_dist_UNSC_length_combined.tex")
  file.rename("token_dist_UNSC_length_combined.pdf","./img/token_dist_UNSC_length_combined.pdf")
}

plot_token_dist_US <- function(){
  # read data to dataframe
  stats <- read.csv("./data/USElectionDebates/corpus/stats_tokens.csv",
                    stringsAsFactors=FALSE)
  debates <- gsub(".*\\_","",list.files("./data/USElectionDebates/",pattern="txt$"))
  debates <- sort(as.numeric(gsub("\\.txt$","",debates)))
  stats[,1] <- sapply(stats[,1],function(x) debates[x+1])
  # aggregate data
  agg <- aggregate(stats,by=list(stats$debate),FUN=sum)
  agg <- agg[-c(2)]
  names(agg)[1] <- "Year"
  names(agg)[c(2,3,4)] <- c("None","Claim","Premise")
  agg <- melt(agg,id.vars ="Year")
  # create file
  tikz("token_dist_US_year.tex", width=11, height=12, standAlone = TRUE)
  # make ggplot object
  g <- ggplot(agg,aes(x=factor(Year),y=value,fill=variable)) +
    geom_bar(stat="identity", color="black", size = 0.5)+
    xlab("\nYear")+ylab("Token Count\n") +
    theme_bw() +
    theme(text = element_text(size=30),
          axis.text.x = element_text(angle = 90, hjust = 1),
          legend.text = element_text(size=25),
          legend.title = element_text(size=25,face = "bold"),
          legend.key = element_rect(colour = "lightgray", fill = "white"),
          plot.title = element_text(hjust=0.5),
          legend.key.size = unit(0.8, "cm")) +
  ggtitle("Token Type Distribution by Year") +
    scale_fill_npg(name="Token\nType",alpha=0.8)
  # process
  print(g)
  dev.off()
  texi2pdf("token_dist_US_year.tex",clean=TRUE)
  file.remove("token_dist_US_year.tex")
  file.rename("token_dist_US_year.pdf","./img/token_dist_US_year.pdf")
  # bin token counts to get new aggregate by length
  stats$total <- rowSums(stats[,c(2:4)])
  stats$bin <- cut(stats$total,seq(0,max(stats$total)+100,100),dig.lab=5)
  agg <- aggregate(stats[c("N","C","P")],by=list(stats$bin),FUN=sum)
  bin <- aggregate(stats[c("bin")],by=list(stats$bin),FUN=length)
  agg <- cbind(agg,bin[,2])
  names(agg) <- c("bin","None","Claim","Premise","count")
  # fill in remaining factor levels where no data is present
  for(level in levels(agg$bin)[-which(levels(agg$bin) %in% agg$bin)]){
    agg <- rbind(agg,c(level,0,0,0,0))
  }
  agg <- melt(agg,id.vars ="bin")
  agg$value <- as.numeric(agg$value)
  agg$type <- "Token Count"
  agg[which(agg[,c("variable")] == "count"),c("type")] <- "Number of Speeches"
  agg[,c("type")] <- factor(agg[,c("type")],levels=c("Token Count","Number of Speeches"))
  sums <- aggregate(agg[,3],by=list(agg$type),FUN=sum)
  # create file
  tikz("token_dist_US_length.tex", width=20, height=15, standAlone = TRUE)
  # make ggplot object
  g <- ggplot(agg,aes(x=bin,y=value,fill=variable)) +
    geom_bar(stat="identity", color="black", size = 0.5)+
    geom_text(aes(x, y, label=lab),
              data=data.frame(x=Inf, y=Inf, lab=c(paste0("$\\Sigma$ = ",formatC(sums[1,2], format = "e", digits = 2)),paste0("$\\Sigma$ = ",prettyNum(sums[2,2],big.mark=","))),
                              type=sums[,1],variable=c("None","Claim")),
              hjust=1.1,vjust=1.5,size=10) +
    xlab("\nBinned Speech Length [Tokens]") +
    ylab("") +
    theme_bw() +
    theme(text = element_text(size=30),
          axis.text.x = element_text(angle = 90, hjust = 1),
          legend.text = element_text(size=25),
          legend.title = element_text(size=25,face = "bold"),
          legend.key = element_rect(colour = "transparent", fill = "white"),
          legend.background=element_blank(),
          plot.title = element_text(hjust=0.5),
          legend.key.size = unit(0.8, "cm"),
          legend.position = c(0.902, 0.84),
          strip.text.x = element_text(size = 27))+
    ## ggtitle("Token Type Distribution by Speech Length") +
    scale_fill_npg(name="Token\nType",alpha=0.8,breaks=c("None","Claim","Premise")) +
    facet_wrap(type~.,nrow=2,scales="free_y")
  # process
  print(g)
  dev.off()
  texi2pdf("token_dist_US_length.tex",clean=TRUE)
  file.remove("token_dist_US_length.tex")
  file.rename("token_dist_US_length.pdf","./img/token_dist_US_length.pdf")
  # aggregate with filtered counts
  stats$type <- "Unfiltered"
  to_add <- stats
  to_add[which(to_add[,5] > 510),c(2,3,4,5)] = 0
  to_add$type <- "Filtered_512"
  stats <- rbind(stats,to_add)
  agg <- aggregate(stats[c("N","C","P")],by=list(stats$bin,stats$type),FUN=sum)
  stats_non_arg <- stats[which(stats[,c("N")] != 0 & stats[,c("C")] == 0 & stats[,c("P")] == 0),]
  stats_non_arg <- aggregate(stats_non_arg$total,by=list(stats_non_arg$bin,stats_non_arg$type),FUN=length)
  stats_arg <- stats[which(stats[,c("C")] != 0 | stats[,c("P")] != 0),]
  stats_arg <- aggregate(stats_arg$total,by=list(stats_arg$bin,stats_arg$type),FUN=length)
  stats_non_arg$variable <- "Non-Argumentative [O]"
  stats_arg$variable <- "Argumentative [A]"
  names(stats_non_arg) <- c("bin","type","value","variable")
  names(stats_arg) <- c("bin","type","value","variable")
  for(type in unique(stats_non_arg$type)){
    for(level in levels(stats_non_arg$bin)[-which(levels(stats_non_arg$bin) %in%
                                                  stats_non_arg[which(stats_non_arg$type == type),"bin"])]){
      stats_non_arg <- rbind(stats_non_arg,c(level,type,0,"Non-Argumentative [O]"))
    }
  }
  for(type in unique(stats_arg$type)){
    for(level in levels(stats_arg$bin)[-which(levels(stats_arg$bin) %in%
                                                  stats_arg[which(stats_arg$type == type),"bin"])]){
      stats_arg <- rbind(stats_arg,c(level,type,0,"Argumentative [A]"))
    }
  }
  stats_combined <- rbind(stats_arg,stats_non_arg)
  stats_combined$type_2 <- "Number of Speeches [S]"
  stats_combined <- melt(stats_combined)
  names(agg)[1] <- "bin"
  names(agg)[2] <- "type"
  names(agg)[c(3,4,5)] <- c("None [N]","Claim [C]","Premise [P]")
  # fill in remaining factor levels where no data is present
  for(type in unique(agg$type)){
    for(level in levels(agg$bin)[-which(levels(agg$bin) %in%
                                        agg[which(agg$type == type),"bin"])]){
      agg <- rbind(agg,c(level,type,0,0,0,0))
    }
  }
  agg <- melt(agg,id.vars =c("bin","type"))
  agg$type_2 <- "Token Count [T]"
  agg <- rbind(agg,stats_combined)
  agg$value <- as.numeric(agg$value)
  agg[,c("type_2")] <- factor(agg[,c("type_2")],levels=c("Token Count [T]","Number of Speeches [S]"))
  agg[,c("type")] <- factor(agg[,c("type")],levels=c("Unfiltered","Filtered_512"))
  levels(agg$type) <- c("Full USED Corpus","Pruned USED Corpus [Sequence Length $\\leq$ 512]")
  sums <- aggregate(agg$value,by=list(agg$type_2,agg$type),FUN=sum)
  sums_cat <- aggregate(agg$value,by=list(agg$type_2,agg$type,agg$variable),FUN=sum)
  # create file
  tikz("token_dist_US_length_combined.tex", width=20, height=15, standAlone = TRUE)
  # make ggplot object
  g <- ggplot(agg,aes(x=bin,y=value,fill=variable)) +
    geom_bar(stat="identity", color="black", size = 0.5)+
    geom_text(aes(x, y, label=lab),
              data=data.frame(x=Inf, y=Inf,
                              lab=c(paste0("$\\Sigma$ [T] = ",formatC(sums[1,3],format = "e", digits = 2),"\n$\\Sigma$ [N] = ",formatC(sums_cat[1,4],format="e",digits=2), "\n$\\Sigma$ [C] = ",formatC(sums_cat[3,4],format="e",digits=2),"\n$\\Sigma$ [P] = ",formatC(sums_cat[5,4],format="e",digits=2)),paste0("$\\Sigma$ [S] = ",prettyNum(sums[2,3],big.mark=","),"\n$\\Sigma$ [A] = ",prettyNum(sums_cat[7,4],big.mark=","),"\n$\\Sigma$ [O] = ",prettyNum(sums_cat[9,4],big.mark=","),"\n"),paste0("$\\Sigma$ [T] = ",formatC(sums[3,3], format = "e", digits = 2),"\n$\\Sigma$ [N] = ",formatC(sums_cat[2,4],format="e",digits=2), "\n$\\Sigma$ [C] = ",formatC(sums_cat[4,4],format="e",digits=2),"\n$\\Sigma$ [P] = ",formatC(sums_cat[6,4],format="e",digits=2)),paste0("$\\Sigma$ [S] = ",prettyNum(sums[4,3],big.mark=","),"\n$\\Sigma$ [A] = ",prettyNum(sums_cat[8,4],big.mark=","),"\n$\\Sigma$ [O] = ",prettyNum(sums_cat[10,4],big.mark=","),"\n")),
                              type=sums[,2],type_2=sums[,1],variable=unique(agg$variable)[1:4]),
              hjust=1.15,vjust=1.2,size=10) +
    xlab("\nBinned Speech Length [Tokens]")+
    ylab("") +
    theme_bw() +
    theme(text = element_text(size=30),
          axis.text.x = element_text(angle = 90, hjust = 1),
          legend.text = element_text(size=25),
          legend.title = element_text(size=25,face = "bold"),
          legend.key = element_rect(colour = "lightgray", fill = "white"),
          plot.title = element_text(hjust=0.5),
          legend.key.size = unit(0.8, "cm"),
          legend.background=element_blank(),
          legend.position = "bottom",
          strip.text.x = element_text(size = 27),
          strip.text.y = element_text(size = 27))+
    ## ggtitle("Token Type Distribution by Speech Length") +
    scale_fill_npg(name="",alpha=0.8) +
    facet_grid(type_2~type,scales="free_y")
  # process
  print(g)
  dev.off()
  texi2pdf("token_dist_US_length_combined.tex",clean=TRUE)
  file.remove("token_dist_US_length_combined.tex")
  file.rename("token_dist_US_length_combined.pdf","./img/token_dist_US_length_combined.pdf")
}

plot_model_evolution <- function(path){
  stats <- read.csv(path,stringsAsFactors=FALSE)
  stats <- melt(stats,id.vars="epoch")
  stats$type <- stats$variable
  # reorder dataframe
  stats <- stats[c(1,4,2,3)]
  levels(stats$type) <- c(levels(stats$type),"loss","accuracy")
  levels(stats$variable) <- c(levels(stats$variable),"training","validation")
  stats[grep("loss",stats$type),"type"] <- "loss"
  stats[grep("acc",stats$type),"type"] <- "accuracy"
  stats[grep("val",stats$variable),"variable"] <- "validation"
  stats[grep("acc|loss|lr",stats$variable),"variable"] <- "training"
  stats[which(stats$type == "lr"),"variable"] <- "lr"
  to_add <- stats[which(stats$type == "lr"),]
  to_add$variable <- "lr"
  stats <- rbind(stats,to_add)
  stats$type <- factor(stats$type, levels=c("lr","accuracy","loss"))
  stats$variable <- factor(stats$variable, levels=c("training","validation","lr"))
  levels(stats$type) <- c("Learning Rate Profile", "Classification Accuracy",
                          "Cross-Entropy Loss")
  levels(stats$variable) <- c("Training", "Validation",
                              "Learning Rate")
  stop_epoch <- stats[which(stats[which(stats[,2] == "Cross-Entropy Loss" & stats[,3] == "Validation"),] ==
                              min(stats[which(stats[,2] == "Cross-Entropy Loss" & stats[,3] == "Validation"),4])),1]
  # create file
  tikz("model_training_evolution.tex", width=20, height=14, standAlone = TRUE)
  # make ggplot object
  g <- ggplot(stats,aes(x=epoch,y=value,color=variable)) +
		geom_point(size=2,alpha=0.9) +
    geom_line(size=2,alpha=0.9)+
    geom_vline(aes(xintercept = stop_epoch, color="Model Checkpoint"),
               linetype="dashed",alpha=0.8)+
    xlab("\nTraining Epoch")+
    ylab("")+
    theme_bw() +
    theme(text = element_text(size=30),
          ## axis.text.x = element_text(angle = 90, hjust = 1),
          legend.text = element_text(size=25),
          legend.title = element_blank(),
          legend.key = element_rect(colour = "lightgray", fill = "white", size=1.2),
          legend.key.size = unit(0.8,"cm"),
          plot.title = element_text(hjust=0.5),
          legend.position="bottom",
          strip.text.x = element_text(size=27)) +
    scale_x_continuous(breaks = round(seq(min(stats$epoch), max(stats$epoch), by = 1),1)) +
    scale_color_manual(values = c("Training"="#F8766D",
                                  "Validation"="#00BA38",
                                  "Learning Rate"="#619CFF",
                                  "Model Checkpoint"="black"),
                       breaks = c("Training","Validation","Learning Rate",
                                  "Model Checkpoint"))+
    ## ggtitle("Token Type Distribution by Speech Length") +
    ## scale_fill_npg(name="Token\nType",alpha=0.8) +
    facet_wrap(~type,scales="free_y",nrow=3) +
    scale_y_continuous(expand = expand_scale(mult = c(0.2, 0.22)))
  # process
  print(g)
  dev.off()
  texi2pdf("model_training_evolution.tex",clean=TRUE)
  file.remove("model_training_evolution.tex")
  file.rename("model_training_evolution.pdf","./img/model_training_evolution.pdf")
}

plot_token_dist_pred_UNSC <- function(path){
  # read data to dataframe
  stats <- read.csv(path,
                    stringsAsFactors=FALSE)
  stats$total <- rowSums(stats[,c(2:4)])
  stats$bin <- cut(stats$total,seq(0,max(stats$total)+100,100),dig.lab=5)
  agg <- aggregate(stats[c("N","C","P")],by=list(stats$bin),FUN=sum)
  names(agg)[1] <- "bin"
  names(agg)[c(2,3,4)] <- c("None [N]","Claim [C]","Premise [P]")
  agg <- melt(agg)
  stats_non_arg <- stats[which(stats[,c("C")] == 0 & stats[,c("P")] == 0),]
  stats_non_arg <- aggregate(stats_non_arg$total,by=list(stats_non_arg$bin),FUN=length)
  stats_arg <- stats[which(stats[,c("C")] != 0 | stats[,c("P")] != 0),]
  stats_arg <- aggregate(stats_arg$total,by=list(stats_arg$bin),FUN=length)
  stats_non_arg$variable <- "Non-Argumentative [O]"
  stats_arg$variable <- "Argumentative [A]"
  stats_combined <- rbind(stats_arg,stats_non_arg)
  stats_combined$type <- "Number of Speeches [S]"
  names(stats_combined)[c(1,2)] <- c("bin","value")
  stats_combined <- melt(stats_combined)
  stats_combined <- stats_combined[,-4]
  agg$type <- "Token Count [T]"
  agg <- rbind(agg,stats_combined)
  agg$type <- factor(agg$type,levels=c("Token Count [T]","Number of Speeches [S]"))
  sums <- aggregate(agg$value,by=list(agg$type),FUN=sum)
  sums_cat <- aggregate(agg$value,by=list(agg$type,agg$variable),FUN=sum)
  # create file
  current <- getOption("tikzLatexPackages")
  ## option("tikzLatexPackages") <- paste0(current,"\\usepackage{amsmath}\n")
  tikz("token_dist_pred_UNSC_length.tex", width=20, height=15, standAlone = TRUE,
       packages =  paste0(current,"\\usepackage{amsmath}\n"))
  # make ggplot object
  g <- ggplot(agg,aes(x=bin,y=value,fill=variable)) +
    geom_bar(stat="identity", color="black", size = 0.5, width = 0.7)+
    geom_text(aes(x, y, label=lab),
              data=data.frame(x=c(0,Inf), y=c(Inf,Inf),
                              lab=c(paste0("$\\Sigma$ [T] = ",formatC(sums[1,2],format = "e", digits = 2),"\n$\\Sigma$ [N] = ",formatC(sums_cat[1,3],format="e",digits=2), "\n$\\Sigma$ [C] = ",formatC(sums_cat[2,3],format="e",digits=2),"\n$\\Sigma$ [P] = ",formatC(sums_cat[3,3],format="e",digits=2)),paste0("$\\begin{aligned}"," \\Sigma ~[\\text{S}] &= \\text{",prettyNum(sums[2,2],big.mark=","),"} \\\\ \\Sigma ~[\\text{A}] &= \\text{",prettyNum(sums_cat[4,3],big.mark=","),"} \\\\ \\Sigma ~[\\text{O}] &= \\text{",prettyNum(sums_cat[5,3],big.mark=","),"} \\end{aligned}$")),type=sums[,1],variable=unique(agg$variable)[1:2]),hjust=c(-0.2,1.2),vjust=c(1.2,5),size=10) +
    xlab("\nBinned Speech Length [Tokens]") +
    ylab("") +
    theme_bw() +
    theme(text = element_text(size=30),
          axis.text.x = element_text(angle = 90, hjust = 1),
          legend.text = element_text(size=25),
          legend.title = element_text(size=25,face = "bold"),
          legend.key = element_rect(colour = "transparent", fill = "white"),
          plot.title = element_text(hjust=0.5),
          legend.key.size = unit(0.8, "cm"),
          legend.position = "bottom",
          legend.background=element_blank(),
          strip.text.x = element_text(size = 27))+
    ## ggtitle("Token Type Prediction in UNSC Corpus") +
    scale_fill_npg(name="",alpha=0.8) +
    facet_wrap(type~.,scales="free_y")
  # process
  print(g)
  dev.off()
  texi2pdf("token_dist_pred_UNSC_length.tex",clean=TRUE)
  file.remove("token_dist_pred_UNSC_length.tex")
  file.rename("token_dist_pred_UNSC_length.pdf","./img/token_dist_pred_UNSC_length.pdf")
}

# parse command-line arguments
parser <- OptionParser()
parser <- add_option(parser, c("-m", "--model-history"),
                     default=NULL, help="Plot model evolution for specified model history csv file")
parser <- add_option(parser, c("-p", "--predictions"),
                     default=NULL, help="Plot prediction token distribution for given csv file")
args <- parse_args(parser)
# manage arguments and overall workflow
if(!is.null(args$m)){
   if(file.exists(args$m)){
     print("Producing model plot")
     plot_model_evolution(args$m)
  }
} else if(!is.null(args$p)){
  if(file.exists(args$p)){
    print("Producing token distribution plots for UNSC predictions")
    plot_token_dist_pred_UNSC(args$p)
  }
} else {
  if(file.exists("./data/USElectionDebates/corpus/stats_tokens.csv")){
    print("Producing token distribution plots for US Election Debates")
    plot_token_dist_US()
  }
  if(file.exists("./data/UNSC/pred/stats_tokens.csv")){
    print("Producing token distribution plots for UNSC")
    plot_token_dist_UNSC()
  }
}
