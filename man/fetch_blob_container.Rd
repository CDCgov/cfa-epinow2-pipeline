% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/azure.R
\name{fetch_blob_container}
\alias{fetch_blob_container}
\title{Load Azure Blob container using credentials in environment variables}
\usage{
fetch_blob_container(container_name)
}
\arguments{
\item{container_name}{The Azure Blob Storage container associated with the
credentials}
}
\value{
A Blob endpoint
}
\description{
This function depends on the following Azure credentials stored in
environment variables:
}
\details{
\itemize{
\item \code{az_tenant_id}: an Azure Active Directory (AAD) tenant ID
\item \code{az_subscription_id}: an Azure subscription ID
\item \code{az_resource_group}: The name of the Azure resource group
\item \code{az_storage_account}: The name of the Azure storage account
}

As a result it is an impure function, and should be used bearing that
warning in mind. Each variable is obtained using
\code{\link[=fetch_credential_from_env_var]{fetch_credential_from_env_var()}} (which will return an error if the
credential is not specified or empty).
}
\seealso{
Other azure: 
\code{\link{download_file_from_container}()},
\code{\link{download_if_specified}()},
\code{\link{fetch_credential_from_env_var}()}
}
\concept{azure}
