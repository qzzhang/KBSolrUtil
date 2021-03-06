
package us.kbase.kbsolrutil;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import javax.annotation.Generated;
import com.fasterxml.jackson.annotation.JsonAnyGetter;
import com.fasterxml.jackson.annotation.JsonAnySetter;
import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonPropertyOrder;


/**
 * <p>Original spec-file type: IndexTaxaInSolrParams</p>
 * <pre>
 * Arguments for the index_taxa_in_solr function
 * </pre>
 * 
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
@Generated("com.googlecode.jsonschema2pojo")
@JsonPropertyOrder({
    "taxa",
    "solr_core",
    "create_report"
})
public class IndexTaxaInSolrParams {

    @JsonProperty("taxa")
    private List<LoadedReferenceTaxonData> taxa;
    @JsonProperty("solr_core")
    private String solrCore;
    @JsonProperty("create_report")
    private Long createReport;
    private Map<String, Object> additionalProperties = new HashMap<String, Object>();

    @JsonProperty("taxa")
    public List<LoadedReferenceTaxonData> getTaxa() {
        return taxa;
    }

    @JsonProperty("taxa")
    public void setTaxa(List<LoadedReferenceTaxonData> taxa) {
        this.taxa = taxa;
    }

    public IndexTaxaInSolrParams withTaxa(List<LoadedReferenceTaxonData> taxa) {
        this.taxa = taxa;
        return this;
    }

    @JsonProperty("solr_core")
    public String getSolrCore() {
        return solrCore;
    }

    @JsonProperty("solr_core")
    public void setSolrCore(String solrCore) {
        this.solrCore = solrCore;
    }

    public IndexTaxaInSolrParams withSolrCore(String solrCore) {
        this.solrCore = solrCore;
        return this;
    }

    @JsonProperty("create_report")
    public Long getCreateReport() {
        return createReport;
    }

    @JsonProperty("create_report")
    public void setCreateReport(Long createReport) {
        this.createReport = createReport;
    }

    public IndexTaxaInSolrParams withCreateReport(Long createReport) {
        this.createReport = createReport;
        return this;
    }

    @JsonAnyGetter
    public Map<String, Object> getAdditionalProperties() {
        return this.additionalProperties;
    }

    @JsonAnySetter
    public void setAdditionalProperties(String name, Object value) {
        this.additionalProperties.put(name, value);
    }

    @Override
    public String toString() {
        return ((((((((("IndexTaxaInSolrParams"+" [taxa=")+ taxa)+", solrCore=")+ solrCore)+", createReport=")+ createReport)+", additionalProperties=")+ additionalProperties)+"]");
    }

}
