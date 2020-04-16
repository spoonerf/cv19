hosp <- "RDE"

rmarkdown::render(
  "Scripts/Staff_Absences.Rmd",
  params = list(hospital = hosp, in_file = paste0("Staff_Absences_",hosp, "_20200408.xlsx")),
  output_file = paste0("/Staff_Absences_",hosp,"_", format(Sys.Date(), "%Y%m%d"), ".pdf"),
  output_dir = here::here("Outputs"))
  
hosp <- "NDDH"

rmarkdown::render(
  "Scripts/Staff_Absences.Rmd",
  params = list(hospital = hosp, in_file = paste0("Staff_Absences_",hosp, "_20200408.xlsx")),
  output_file = paste0("/Staff_Absences_",hosp,"_", format(Sys.Date(), "%Y%m%d"), ".pdf"),
  output_dir = here::here("Outputs"))

