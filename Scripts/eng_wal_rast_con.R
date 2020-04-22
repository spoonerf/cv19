#####Creating a raster of england and wales 
# which shows how connected each cell is.
# Based on distance to the nearest transport hub - train station
# or airport and the busy-ness of that transport hub

library(janitor)
library(raster)
library(sf)
library(fasterize)
library(readr)
library(dplyr)

#### Loading in map of the  UK and rasterizing it - laptop can't seem to handle a resolution smaller than 0.05 degs
uk <- st_read(here::here("Data/Spatial/Counties_and_Unitary_Authorities_December_2016_Full_Clipped_Boundaries_in_England_and_Wales/Counties_and_Unitary_Authorities_December_2016_Full_Clipped_Boundaries_in_England_and_Wales.shp"))
ukr <- raster::raster(res = c(0.05,0.05), ext = extent(uk))
ukr <- fasterize(uk, ukr)

xy <- xyFromCell(ukr, 1:ncell(ukr))

#### Loading in airport data - annual passenger data from 2019 - source: 
airp <- clean_names(read_csv("Data/Spatial/uk_airports.csv")) %>% 
          dplyr::select(transport_hub = airport, long, lat, annual_passengers = feb_2019_jan_2020) %>% #https://www.caa.co.uk/Data-and-analysis/UK-aviation-market/Airports/Datasets/UK-Airport-data/Airport-data-2020-01/
          mutate(transport_type = "Airport")

#### Loading in train station data - annual passengers from 2018-2019 - source:
train <- clean_names(readxl::read_xlsx("Data/Spatial/estimates-of-station-usage-2018-19.xlsx", sheet = "Estimates of Station Usage")) %>% 
  dplyr::select(transport_hub = station_name, os_grid_easting, os_grid_northing, annual_passengers = x1819_entries_exits) %>% 
  mutate(transport_type = "Train")

#### Transforming the train station coordinates from os grid to wgs84
coords <- cbind(train$os_grid_easting, train$os_grid_northing)
latlong <- "+init=epsg:4326"

coordinates(train) <- c("os_grid_easting", "os_grid_northing")
proj4string(train) <- CRS("+init=epsg:27700") # WGS 84
CRS.new <- CRS(latlong)
train_new <- data.frame(spTransform(train, CRS.new)) %>% 
  dplyr::select(transport_hub, 
                long = os_grid_easting, 
                lat = os_grid_northing,
                annual_passengers,
                transport_type)

#### Combining the train and airport data
trair <- rbind(train_new, airp)
trair_xy <- cbind(trair$long, trair$lat)

#### Calculating the distance of each cell in the raster to each transport hub - in km
dist_out <- apply(trair_xy,1, function(x) spDistsN1(xy, x, longlat = TRUE))
xy_trans_df <- data.frame(x= xy[,1],y = xy[,2] ,dist_out)

#### Lengthening the distance data and adding the station names back in 
xy_trans_lng <- tidyr::pivot_longer(xy_trans_df, cols = -c(x,y) ) 
xy_trans_lng$name <- rep(trair$transport_hub, nrow(xy))
colnames(xy_trans_lng) <- c("long","lat","transport_hub", "distance_km")

#### Adding the passenger data back in by joining by station name 
# and calculating connectedness by multiplying the inverse distance of each
# transport hub by the number of annual passengers and then summing this for each cell.
xy_trans_lng_pass <- xy_trans_lng %>% 
  left_join(., trair[,c("transport_hub", "transport_type","annual_passengers")], by = "transport_hub") %>% 
  filter(!is.na(annual_passengers)) %>% 
  group_by(long,lat) %>% 
  mutate(connectedness_ann = (1/distance_km)* annual_passengers) %>%  #not sure if this is the best measure of connectedness
 # top_n(n= -3, wt = distance_km) %>% 
  summarise(sum_connected_ann = sum(connectedness_ann)) 

##### Turning the data back into a raster
ras_con <- rasterFromXYZ(xy_trans_lng_pass)

#### Plotting this raster
plot(ras_con)

#### Looks better when logged
plot(log10(ras_con))

#### Masking it out so it's just the UK
ukm <- mask(ras_con, uk)
plot(log10(ukm))
