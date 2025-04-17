library(dplyr)
library(readr)
library(ggplot2)
library(cluster)
library(factoextra)
library(tidyverse)
library(NbClust)
library(scales)
library(mclust) 
library(patchwork)
library(knitr) # Print table for github

# Read data
results = read_csv("student_results.csv")

# Conduct structure and missing values
glimpse(results)
colSums(is.na(results))

# Select useful variables (courses) for analysis
data = results %>%
  select(-Student_ID, -Class)

# Print summary as a table format
kable(summary(data), caption = "Statistical results of data")

# Scaled data
data_scaled = scale(data)

# Apply PCA
pca = prcomp(data_scaled, center = TRUE, scale. = TRUE)
explained_var = pca$sdev^2 / sum(pca$sdev^2)
cum_var = cumsum(explained_var)
n_components_90 = which(cum_var >= 0.9)[1]

plot(cum_var, type = "b", pch = 19, col = "blue",
     xlab = "Number of Principal Components", ylab = "Cumulative Explained Variance",
     main = "Cumulative Explained Variance by PCA Components")
abline(h = 0.9, col = "red", lty = 2)
abline(v = n_components_90, col = "darkgreen", lty = 2)
legend("bottomright",
       legend = c("Cumulative Variance", "90% Threshold", paste(n_components_90, "Components")),
       col = c("blue", "red", "darkgreen"),
       lty = c(1, 2, 2), pch = c(19, NA, NA),
       bty = "n")

# Scatter PC1 & PC2
fviz_pca_ind(pca, axes = c(1, 2), geom = "point", pointshape = 21, pointsize = 2, fill.ind = "blue", col.ind = "blue", addEllipses = FALSE) +
  ggtitle("Scatter Plot of First Two Principal Components")

# Use the first 5 principal components 
pca_scores = pca$x[, 1:5]

# Automatically calculate the silhouette of k value
fviz_nbclust(pca_scores, kmeans, method = "silhouette", k.max = 10)

# WSS elbow method
fviz_nbclust(pca_scores, kmeans, method = "wss") 

# Gap statistics
fviz_nbclust(pca_scores, kmeans, method = "gap_stat") # After reading three figures, centers = 2 & 3

# k = 2
set.seed(42)
kmeans_result_k2 = kmeans(pca$x[, 1:5], centers = 2, nstart = 25)
cluster_assignments_k2 = kmeans_result_k2$cluster

# k = 3
set.seed(42)
kmeans_result_k3 = kmeans(pca$x[, 1:5], centers = 3, nstart = 25)
cluster_assignments_k3 = kmeans_result_k3$cluster

# PC1 & PC2
pc1_label = paste0("PC1 (", round(summary(pca)$importance[2,1]*100, 1), "%)")
pc2_label = paste0("PC2 (", round(summary(pca)$importance[2,2]*100, 1), "%)")

# Plot k = 2
plot_k2 = ggplot(data.frame(PC1 = pca$x[,1], PC2 = pca$x[,2], Cluster = as.factor(cluster_assignments_k2)), aes(x = PC1, y = PC2, color = Cluster)) +
  geom_point(alpha = 0.8, size = 2) + labs(title = "K-means Clustering (k = 2)", x = pc1_label, y = pc2_label) + theme_minimal()

# Plot k = 3
plot_k3 = ggplot(data.frame(PC1 = pca$x[,1], PC2 = pca$x[,2], Cluster = as.factor(cluster_assignments_k3)), aes(x = PC1, y = PC2, color = Cluster)) +
  geom_point(alpha = 0.8, size = 2) + labs(title = "K-means Clustering (k = 3)", x = pc1_label, y = pc2_label) + theme_minimal()

# Combine two figures
plot_k2 + plot_k3

# Hierarchical clustering
dists = dist(pca_scores, method = "euclidean")
hc = hclust(dists, method = "ward.D2")

fviz_dend(hc, k=NULL, cex=0.5, main = "Hierarchical Clustering Dendrogram", color_labels_by_k=FALSE, rect=FALSE)

# Evaluate the optimal cluster numbers for hierarchical clustering
evaluate_hc_k = function(pca_scores, method = "silhouette", k_range = 2:10, dist_method = "euclidean", hc_method = "ward.D2") {
  dists = dist(pca_scores, method = dist_method)
  hc = hclust(dists, method = hc_method)
  
  if (method == "silhouette") {
    sil_scores = c()
    for (k in k_range) {
      clusters = cutree(hc, k = k)
      sil = silhouette(clusters, dists)
      sil_scores[k - 1] = mean(sil[, 3])  # silhouette width
    }
    
    # Plot silhouette scores
    plot(k_range, sil_scores, type = "b", pch = 19,
         xlab = "Number of Clusters (k)", ylab = "Average Silhouette Width",
         main = "Silhouette Method for Optimal k")
    abline(v = k_range[which.max(sil_scores)], col = "blue", lty = 2)
    
    cat("Best k by silhouette method:", k_range[which.max(sil_scores)], "\n")
    return(invisible(sil_scores))
    
  } else if (method == "gap") {
    # Gap statistic via clusGap
    gap_stat = clusGap(pca_scores, FUN = function(x, k) {
      list(cluster = cutree(hclust(dist(x, method = dist_method), method = hc_method), k = k))
    }, K.max = max(k_range), B = 50)  # You can increase B for stability
    
    fviz_gap_stat(gap_stat)
    best_k = which.max(gap_stat$Tab[, "gap"])
    cat("Best k by gap statistic:", best_k, "\n")
    return(invisible(gap_stat))
    
  } else {
    stop("Please choose method = 'silhouette' or method = 'gap'")
  }
}

evaluate_hc_k(pca_scores, method = "silhouette")
evaluate_hc_k(pca_scores, method = "gap")

# k=2
dend_k2=fviz_dend(hc, k=2, cex=0.5, k_colors=c("blue", "red"), rect=TRUE, rect_fill=TRUE, main ="Hierarchical Clustering (k=2)")
hc_clusters_k2 = cutree(hc, k=2)

# k=3
dend_k3=fviz_dend(hc, k=3, cex=0.5, k_colors=c("blue", "red","green"), rect=TRUE, rect_fill=TRUE, main ="Hierarchical Clustering (k=3)")
hc_clusters_k3 = cutree(hc, k=3)

dend_k2+dend_k3

# Combine figures for k-means and hierarchical clustering
kmeans_clusters_k2 = kmeans_result_k2$cluster
kmeans_plot_k2 = fviz_cluster(list(data = pca_scores, cluster = kmeans_clusters_k2),
             geom = "point", ellipse.type = "convex",
             main = "K-means Clustering (k = 2)")

kmeans_clusters_k3 = kmeans_result_k3$cluster
kmeans_plot_k3 = fviz_cluster(list(data = pca_scores, cluster = kmeans_clusters_k3),
                           geom = "point", ellipse.type = "convex",
                           main = "K-means Clustering (k = 3)")

hc_plot_k2=fviz_cluster(list(data = pca_scores, cluster = hc_clusters_k2),
             geom = "point", ellipse.type = "convex",
             main = "Hierarchical Clustering (k = 2)")

hc_plot_k3=fviz_cluster(list(data = pca_scores, cluster = hc_clusters_k3),
                        geom = "point", ellipse.type = "convex",
                        main = "Hierarchical Clustering (k = 3)")

kmeans_plot_k2 + kmeans_plot_k3 + hc_plot_k2 + hc_plot_k3

# Put k-means and hierarchical cluster to original "Class"
compare_with_class = results %>%
  mutate(Kmeans_k2 = kmeans_clusters_k2, Kmeans_k3 = kmeans_clusters_k3, Hierarchical_k2 = hc_clusters_k2, Hierarchical_k3 = hc_clusters_k3) %>%
  select(Student_ID, Class, Kmeans_k2, Kmeans_k3, Hierarchical_k2, Hierarchical_k3)

# Evaluate ADI
compare_with_class$Class = as.factor(compare_with_class$Class)

Kmeans_k2 = kmeans_clusters_k2
Kmeans_k3 = kmeans_clusters_k3
Hierarchical_k2 = hc_clusters_k2
Hierarchical_k3 = hc_clusters_k3

methods = c("K-means", "K-means", "Hierarchical", "Hierarchical")
k_values = c(2, 3, 2, 3)
clusters = list(compare_with_class$Kmeans_k2,
                compare_with_class$Kmeans_k3,
                compare_with_class$Hierarchical_k2,
                compare_with_class$Hierarchical_k3)

ari_scores = sapply(clusters, function(cluster) {adjustedRandIndex(cluster, compare_with_class$Class)})

ari_table = data.frame(Method = methods, K = k_values, ARI = round(ari_scores, 4))

# Print results as a Table format
kable(ari_table, caption = "Adjusted Rand Index (ARI) for Cluster vs Class")

ari_table$Label <- paste0(ari_table$Method, " (k=", ari_table$K, ")")

ggplot(ari_table, aes(x = Label, y = ARI, fill = Method)) +
  geom_bar(stat = "identity") +
  labs(title = "Adjusted Rand Index (ARI) by Clustering Method and k",
       x = "Method and k", y = "ARI") +
  theme_minimal()

# Compare k-means, k = 2 with original Class
conf_mat = table(Kmeans_k2 = compare_with_class$Kmeans_k2, Class = compare_with_class$Class)
conf_df = as.data.frame(conf_mat)
conf_df$Class = factor(conf_df$Class, levels = c("First Class", "Second Class", "Lower Class", "Pass Class", "Fail"))

# heatmap
ggplot(conf_df, aes(x = Class, y = as.factor(Kmeans_k2), fill = Freq)) +
  geom_tile(color = "white") +
  geom_text(aes(label = Freq), color = "black", size = 5) +
  scale_fill_gradient(low = "white", high = "red") +
  labs(title = "Confusion Matrix: K-means (k = 2) vs Original Class",
       x = "Class",
       y = "K-means Cluster",
       fill = "Count") +
  theme_minimal()

























