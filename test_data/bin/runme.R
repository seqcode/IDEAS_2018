mystop<-function(ms, mailfrom, email, logfile)
{	if(!is.null(logfile))
	{	write(ms, file=logfile, append=T);
	}
#	if(!is.null(email))
#	{	sendmail(from=mailfrom, to=email, subject="IDEAS error", msg=ms);
#	}
	stop(ms);
}

#Sys.getenv(c("PATH"));
#Sys.setenv(PATH="usr/bin/:/usr/local/bin:/bin");

args<-commandArgs(trailingOnly=TRUE);
if(length(args) != 3) 
{	stop("Exactly three arguments are needed: data_file para_file work_dir");
}
datafile = args[1];
parafile = args[2];
tmpfolder = args[3];
if(substring(tmpfolder, nchar(tmpfolder)) != "/") { tmpfolder = paste(tmpfolder, "/",sep=""); }

prepmat=1;
ideas=1;
maketrack=1;

id="test";
build="hg38";
prenorm=0;
signal=5;
log2val=1;
norm=0;
G=0;
C=0;
minerr=0.5;
maxerr=0;
splitstateflag=0;
smooth=1;
burnin=50;
mcmc=10;
email=NULL;
bedfile=NULL;
statefiles=NULL;
targetURL="http://bx.psu.edu/~yuzhang/tmp/";
thread=1;
split=NULL;
train=20;
trainsz=10000;
impute="All";
otherpara=NULL;
mycol=NULL;
sc=NULL;
cellinfo=NULL;
statename=NULL;
prevstate=NULL;
matrix=NULL;
cap=100000000;
#mailfrom="ideas@bx.psu.edu";

logfile=paste(tmpfolder, "log.txt", sep="");
#tmpurl=sub("/data/server/htroot/", "http://ideas.bx.psu.edu/",tmpfolder);
tmpurl=tmpfolder;

para=gsub("=","",readLines(parafile));
for(i in 1:length(para))
{ 	j=as.integer(regexpr("#",para[i])); 
	if(j>0) { para[i]=substring(para[i], 1, j-1); } 
	para[i]=gsub("\t","",para[i]);
}
para=para[which(para!="")];
print(para);
rexp="^(\\w+)\\s+(.*)$"
para=data.frame(sub(rexp,"\\1",para), sub(rexp,"\\2",para));
if(length(para)==0)
{       write("ERROR all the parameters are missing", file=logfile, append=TRUE);
        quit("no", 1, FALSE);
}
para=as.matrix(para);
for(i in 1:dim(para)[2]) para[,i]=gsub(" |\t|\"","",para[,i]);
message(para);
if(length(para)>0)
{	for(i in 1:dim(para)[1])
	{	if(para[i,1]=="prepmat") { prepmat = as.integer(para[i,2]); }
		if(para[i,1]=="ideas") { ideas = as.integer(para[i,2]); }
		if(para[i,1]=="maketrack") { maketrack = as.integer(para[i,2]); }
		if(para[i,1]=="id") { id = para[i,2]; }
		if(para[i,1]=="build") { build = para[i,2]; }
		if(para[i,1]=="prenorm") { prenorm = as.integer(para[i,2]); }
		if(para[i,1]=="norm") { norm = as.integer(para[i,2]); }
		if(para[i,1]=="sig" & para[i,2]=="max") { signal = 8; }
		if(para[i,1]=="log2") { log2val = as.numeric(para[i,2]); }
		if(para[i,1]=="num_state") { G = as.numeric(para[i,2]); }
		if(para[i,1]=="num_start") { C = as.numeric(para[i,2]); }
		if(para[i,1]=="minerr") { minerr = as.numeric(para[i,2]); }
		if(para[i,1]=="maxerr") { maxerr = as.numeric(para[i,2]); }
		if(para[i,1]=="splitstate") { splitstateflag=as.integer(para[i,2]); }
		if(para[i,1]=="smooth") { smooth = as.integer(para[i,2]); }
		if(para[i,1]=="burnin") { burnin = as.integer(para[i,2]); }
		if(para[i,1]=="sample") { mcmc = as.integer(para[i,2]); }
		if(para[i,1]=="email") { email = para[i,2]; }
		if(para[i,1]=="bed") { bedfile = para[i,2]; }	
		if(para[i,1]=="hubURL") { targetURL = para[i,2]; }
		if(para[i,1]=="statefiles")
		{	statefiles=as.matrix(read.table(para[i,2]));
		}
		if(para[i,1]=="thread") { thread = as.integer(para[i,2]); }
		if(para[i,1]=="split") { split = para[i,2]; }
		if(para[i,1]=="train") { train = as.integer(para[i,2]); }
		if(para[i,1]=="trainsz") { trainsz = as.integer(para[i,2]); }
		if(para[i,1]=="impute") { impute = unlist(strsplit(para[i,2],",")); }
		if(para[i,1]=="otherpara") { otherpara = para[i,2]; }
		if(para[i,1]=="prevstate") { prevstate = para[i,2]; }
		if(para[i,1]=="markcolor") { t=as.integer(unlist(strsplit(para[i,2],",|;")));if(length(t)%%3!=0){write("Length of color code is not in mulple of 3 (for R,G,B); User provided color code is not used.", file=logfile, append=T);}else{mycol=t(array(t,dim=c(3,length(t)/3)));} }
		if(para[i,1]=="statecolor") { sc=as.matrix(read.table(para[i,2])); }
		if(para[i,1]=="statename") { statename=as.matrix(read.table(para[i,2])); } 
		if(para[i,1]=="cellinfo") { cellinfo=as.matrix(read.table(para[i,2],comment="!")); } 
		if(para[i,1]=="matrix") { matrix = para[i,2]; }
		if(para[i,1]=="cap") { cap = as.numeric(para[i,2]); }
	}
}

#if(!is.null(email))
#{	library(sendmailR);
#}

#TODO where should we put these?
if(length(bedfile) == 0 & (build == "hg38" | build == "hg19" | build == "mm9" | build == "mm10"))
{	#bedfile = paste("../htroot/genomes/", build, ".bed", sep="");
	bedfile = paste("data/", build, ".bed", sep="");
}

path=Sys.getenv("PATH");
#path=paste(path,"../bin/",sep=":");
path=paste(path,"./bin/",sep=":");
Sys.setenv("PATH"=path);

if(file_test("-d", tmpfolder) == FALSE)
{	
	#can't write to log file because it is in the missing folder
	#TODO check email
	write(paste("Error bad folder", tmpfolder), stderr());
}
options(scipen=1000);

#-------------------(1) data process-------------------------
if(prepmat)
{	write("------[ Preprocessing Data ]------", file=logfile, append=TRUE);
	write(date(), file=logfile, append=TRUE);
	inputfolder = paste(tmpfolder, "Input/", sep="");
	#prep = paste("../bin/prepMat", datafile, "-bed", bedfile, "-wsz 200", "-dir", inputfolder, "-c", signal);
	prep = paste("bin/prepMat", datafile, "-bed", bedfile, "-build", build, "-wsz 200", "-dir", inputfolder, "-c", signal);
	if(prenorm==1) { prep = paste(prep, "-norm"); }
	write(prep, file=logfile, append=TRUE);
	system(prep);

	missing=NULL;
	fsz = file.info(paste(inputfolder, "missingdata.txt", sep=""))$size;
	if(is.na(fsz)==T) { mystop("Data processing failed", mailfrom, email, logfile); }
	missing=readLines(paste(inputfolder, "missingdata.txt", sep=""));
	write(paste("Processed data are stored in ", tmpfolder, "Input/", sep=""), file=logfile, append=TRUE); 
	if(length(missing) > 0) 
	{	write(paste("There are missing data file(s) listed in ", tmpurl, "Input/missingdata.txt", sep=""), file=logfile, append=T);
		if(length(missing)>=length(readLines(datafile)))
		{	mystop("All data files are missing!", mailfrom, email, logfile);	
		}
	} 
}

#-------------------(2) run ideas----------------------------
if(ideas)
{	write("------[ IDEAS Analysis ]------", file=logfile, append=TRUE);
	write(date(), file=logfile, append=TRUE);
	if(prepmat & length(matrix) == 0)
	{	x=as.matrix(read.table(datafile));
		t=match(x[,3],missing); 
		x[,3]=paste(inputfolder, x[,1],".",x[,2],".bed.gz", sep="");
		x=x[is.na(t)==T,];
		if(length(x)==0) { mystop("No input data found.", mailfrom, email, logfile); }
		datafile = paste(tmpfolder, id, ".input", sep="");
		write.table(array(x,dim=c(length(x)/3,3)), datafile, quote=F,row.names=F,col.names=F);
	} else if(length(matrix) != 0)
	{	fetch = paste("/usr/bin/wget -nv --no-check-certificate -O", datafile, matrix);
	#	write(fetch, file=logfile, append=TRUE);
	#	system(fetch);	
		write("Done downloading matrix", file=logfile, append=TRUE);
		bedfile='';
	}
	if(file.exists(paste(tmpfolder, id, ".state", sep=""))) { system(paste("rm ", tmpfolder,id,".state",sep=""));}
	if(file.exists(paste(tmpfolder, id, ".para", sep=""))) { system(paste("rm ", tmpfolder,id,".para",sep=""));}
	if(file.exists(paste(tmpfolder, id, ".cluster", sep=""))) { system(paste("rm ", tmpfolder,id,".cluster",sep=""));}

	#runideas = paste("bin/ideas", tmpdatafile, bedfile, "-o", paste(tmpfolder, id, sep=""), "-sample", burnin, mcmc, "-thread", thread);
	runideas = paste("Rscript bin/ideaspipe.R", datafile, bedfile, "-o", paste(tmpfolder, id, sep=""), "-sample", burnin, mcmc, "-thread", thread);
	if(train>0 & trainsz>0) { runideas = paste(runideas, "-randstart", train, trainsz); }
	if(length(split)==1) { runideas = paste(runideas, "-split", split); }	
	if(impute != "All") { runideas = paste(runideas, "-impute", impute); }
	if(log2val > 0) { runideas = paste(runideas, "-log2", log2val); }
	if(norm) { runideas = paste(runideas, "-norm"); }
	if(smooth > 0) { runideas = paste(runideas, "-hp"); }
	if(G > 0) { runideas = paste(runideas, "-G", G); }
	if(C > 0) { runideas = paste(runideas, "-C", C); }
	if(minerr > 0) { runideas = paste(runideas, "-minerr", minerr); }
	if(maxerr > 0) { runideas = paste(runideas, "-maxerr", maxerr); }
	if(cap < 100000000) { runideas = paste(runideas, "-cap", cap); }
	if(length(otherpara)>0) { runideas = paste(runideas, "-otherpara", otherpara); }
	if(length(prevstate)>0) { runideas = paste(runideas, "-prevrun", prevstate); }
	if(splitstateflag==1) { runideas = paste(runideas, "-splitstate"); }
	write(runideas, file=logfile, append=TRUE);
	system(runideas);

	fsz1 = file.info(paste(tmpfolder, id, ".state", sep=""))$size;
	fsz2 = file.info(paste(tmpfolder, id, ".para", sep=""))$size;
	fsz3 = file.info(paste(tmpfolder, id, ".cluster", sep=""))$size;
	if(is.na(fsz1)==T | is.na(fsz2)==T | is.na(fsz3)==T | fsz1==0 | fsz2==0 | fsz3==0)
	{	mystop("IDEAS execution was unsuccessful.", mailfrom, email, logfile); 
	} else {	write(paste("IDEAS ran successfully, results in ", tmpurl, "\n", sep=""), file=logfile, append=TRUE); }
}

#-------------------(3) create tracks-----------------------
if(maketrack)
{	write("------[ Create Custom Tracks ]------", file=logfile, append=TRUE);
	write(date(), file=logfile, append=TRUE);
	source("bin/createGenomeTracks.R");

	if(length(statefiles)==0)
	{	if(length(split)==1) 
		{	targetfile=paste(tmpfolder,as.matrix(read.table(split))[,1],sep="");	
		} else {	targetfile=paste(tmpfolder, id, sep="");	}
	} else
	{	targetfile=gsub(".state","",statefiles);
	}
	statefiles=paste(targetfile, ".state",sep="");

	if(length(sc)==0)
	{	if(length(mycol)>0) 
		{	mc[1:min(dim(mycol)[1],l),]=mycol[1:min(dim(mycol)[1],l),];
		} else
		{	mc = NULL;
		}
	#	x=read.table(paste(targetfile[1],".para",sep=""), comment="!", nrows=1);
	#	l=as.integer(regexpr("\\*",as.matrix(x)));
	#	l=min(which(l>0))-2;
	#	x=as.matrix(read.table(paste(targetfile[1], ".para", sep="")));
	#	if(length(targetfile)>1)
	#	{	for(i in 2:length(targetfile))
	#			x=x+as.matrix(read.table(paste(targetfile[i],".para",sep="")));
	#	}
	#	p=x[,1]/sum(x[,1]);
	#	m=array(as.matrix(x[,1:l+1]/x[,1]),dim=c(dim(x)[1],l));
	#	sc=stateColor(m, mc);
		sc=createHeatmap(paste(targetfile[1],".para",sep=""),markcolor=mc,scale=F);
	}

	hubid=id;
	genomeid=build;
	#genomefile=paste("../htroot/genomes/", build, ".genome", sep="");
	genomefile=paste("data/", build, ".genome", sep="");
	trackfolder=paste(tmpfolder, "Tracks/", sep="");

	rt=run(statefiles, hubid, genomeid, genomefile, sc, targetURL, trackfolder,cellinfo=cellinfo, statename=statename);
	if(rt==0) 
	{	mystop("Creation of custom tracks failed.", mailfrom, email, logfile); 
	} else { write(paste("Tracks created successfully in ", tmpurl, "Tracks/", "\n", sep=""), file=logfile, append=TRUE); }

	write(date(), file=logfile, append=TRUE);
	hubUrl=paste(tmpurl, "Tracks/hub_", hubid, ".txt", sep="");
	write(paste("The hub url is ", hubUrl), file=logfile, append=TRUE);
	write(paste("A direct link to the VISION browser is http://main.genome-browser.bx.psu.edu/cgi-bin/hgTracks?db=", build, "&hubUrl=", hubUrl, "\n", sep=""), file=logfile, append=TRUE);
        donemsg=paste("IDEAS execution was successful.  Results are available with the hub URL", hubUrl);
} else
{	donemsg=paste("IDEAS execution was successful.");
}

write("Done!\n", file=logfile, append=TRUE);
#if (!is.null(email)) {
#        sendmail(from=mailfrom,to=email,subject="IDEAS run is successful", msg=donemsg);
#}
