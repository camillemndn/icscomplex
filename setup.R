knitr::opts_chunk$set(
	collapse = TRUE,
	comment = "#>",
	warning = FALSE,
	dpi = 300,
	fig.height = 10,
	fig.width = 15,
	dev.args = list(bg = "white")
)

library(ggplot2)
theme_set(theme_minimal(base_size = 16))
theme_legend_inside <- theme(
	legend.position = "inside",
	legend.position.inside = c(.05, .95),
	legend.justification = c("left", "top"),
	legend.box.just = "left",
	legend.margin = margin(6, 6, 6, 6)
)
theme_legend_inside_right <- theme(
	legend.position = "inside",
	legend.position.inside = c(.95, .95),
	legend.justification = c("right", "top"),
	legend.box.just = "right",
	legend.margin = margin(6, 6, 6, 6)
)
