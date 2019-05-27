apt update
apt install r-base r-base-dev
apt install libcurl4-openssl-dev libssl-dev libxml2-dev

gcsfuse --implicit-dirs fg-shared-analysis-registry /home/aganna/bucket



library(data.table)
require(dplyr)
library(ggplot2)

all_file <- list.files("/home/aganna/data/")

longitu <- NULL
for (i in all_file)
{
	d <- fread(i)
	longitu <- rbind(longitu,d)
	print(which(i==all_file))
}


write.table(longitu,file="/home/aganna/data/FINNGEN_ENDPOINTS_DF3_FINAL_withpw_2019-03-28_longitudinal_ALL.tsv", col.names=T, row.names=F, quote=F, sep="\t")

save(longitu,file="/home/aganna/data/FINNGEN_ENDPOINTS_DF3_FINAL_withpw_2019-03-28_longitudinal_ALL.Rdata")


load("/home/aganna/data/FINNGEN_ENDPOINTS_DF3_FINAL_withpw_2019-03-28_longitudinal_ALL.Rdata")

longituS <- longitu[order(longitu$FINNGENID,longitu$ENDPOINT,longitu$EVENT_AGE),]
longituS2 <- longituS %>% group_by(FINNGENID,ENDPOINT) %>% mutate(diffage = EVENT_AGE - lag(EVENT_AGE))
longituS3 <- longituS2[is.na(longituS2$diffage) | longituS2$diffage > (28/365.25),]
longituS3 <- longituS3 %>% mutate(diffage = EVENT_AGE - lag(EVENT_AGE, default=EVENT_AGE[1]),count_events = n())
longituS3 <- longituS3 %>% mutate(diffagecum = cumsum(diffage))
longituS3 <- longituS3 %>% mutate(rehosp = ifelse(any(diffagecum < 0.5 & diffagecum != 0 ),1,0))

save(longituS3,file="/home/aganna/data/FINNGEN_ENDPOINTS_DF3_FINAL_withpw_2019-03-28_longitudinal_ALL_S3.Rdata")

longituU <- longituS3 %>% filter(diffage == 0)
write.table(longituU,file="/home/aganna/data/unique_events_with_stats.tsv", col.names=T, row.names=F, quote=F, sep="\t")


info <- fread("/home/aganna/data/minimidata_and_VRKdata_DF3_V1_.txt")
longituUM <- inner_join(longituU,info)

## Events per enpoint

longituUM_stats_SEX <- longituUM %>% select(FINNGENID, ENDPOINT, count_events, SEX, rehosp) %>% group_by(ENDPOINT,SEX) %>% summarize(mean_count = mean(count_events),median_count = median(count_events),min_count = min(count_events),max_count = max(count_events), n_hops = sum(rehosp), n_ind = n(), perc_hosp = n_hops/n_ind)

longituUM_stats_NOSEX <- longituUM %>% select(FINNGENID, ENDPOINT, count_events, rehosp) %>% group_by(ENDPOINT) %>% summarize(mean_count = mean(count_events),median_count = median(count_events),min_count = min(count_events),max_count = max(count_events), n_hops = sum(rehosp), n_ind = n(), perc_hosp = n_hops/n_ind, SEX="all")

longituU_stats <- bind_rows(longituUM_stats_SEX,longituUM_stats_NOSEX)

tt <- longituU_stats[longituU_stats$SEX=="all",]

write.table(longituU_stats,file="/home/aganna/data/enpoints_longitudinal_with_stats.tsv", col.names=T, row.names=F, quote=F, sep="\t")


## Distribution of number of repeated events per endpoint ##
pdf("/home/aganna/data/test.pdf", height=4,width=12)
longituU_stats$ENDPOINT_O <- ordered(longituU_stats$ENDPOINT,levels=unique(tt$ENDPOINT[order(-tt$median_count)]))
ggplot(aes(x=ENDPOINT_O,y=median_count),data=longituU_stats) + geom_bar(stat="identity") + theme_bw() + facet_wrap(~SEX) + ylab("Median number of repeated events per enpoint") + xlab("Endpoints") + theme(axis.text.x=element_blank(), axis.ticks.x=element_blank())
dev.off()


## Distribution of number of repeated events per individual ##
info <- fread("/home/aganna/data/minimidata_and_VRKdata_DF3_V1_.txt")
tt <- inner_join(longituS3,info)
tt$age_2018 <- 2018-(tt$BL_YEAR - tt$BL_AGE)
tt$age_2018_cat <- cut(tt$age_2018,c(0,20,40,60,80,200), include.lowest = TRUE)

tt_stats_SEX_IND <- tt %>% select(FINNGENID, ENDPOINT, count_events, SEX, age_2018_cat) %>% group_by(FINNGENID,SEX,age_2018_cat) %>% summarize(count = n())

pdf("/home/aganna/data/test.pdf", height=6,width=11)
ggplot(aes(x=count),data=tt_stats_SEX_IND) + geom_histogram(bins=100) + theme_bw() + facet_grid(SEX~age_2018_cat) + xlab("Median number of repeated events per individual")
dev.off()

tt_stats_SEX_IND %>% group_by(SEX,age_2018_cat) %>% summarize(median = median(count))

