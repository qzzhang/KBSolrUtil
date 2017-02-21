
package us.kbase.kbsolrutil;

import java.util.HashMap;
import java.util.Map;
import javax.annotation.Generated;
import com.fasterxml.jackson.annotation.JsonAnyGetter;
import com.fasterxml.jackson.annotation.JsonAnySetter;
import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonPropertyOrder;


/**
 * <p>Original spec-file type: LoadedReferenceTaxonData</p>
 * <pre>
 * Struct containing data for a single item in the input parameter of index_taxa_in_solr
 * </pre>
 * 
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
@Generated("com.googlecode.jsonschema2pojo")
@JsonPropertyOrder({
    "ws_ref"
})
public class LoadedReferenceTaxonData {

    @JsonProperty("ws_ref")
    private String wsRef;
    private Map<String, Object> additionalProperties = new HashMap<String, Object>();

    @JsonProperty("ws_ref")
    public String getWsRef() {
        return wsRef;
    }

    @JsonProperty("ws_ref")
    public void setWsRef(String wsRef) {
        this.wsRef = wsRef;
    }

    public LoadedReferenceTaxonData withWsRef(String wsRef) {
        this.wsRef = wsRef;
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
        return ((((("LoadedReferenceTaxonData"+" [wsRef=")+ wsRef)+", additionalProperties=")+ additionalProperties)+"]");
    }

}
