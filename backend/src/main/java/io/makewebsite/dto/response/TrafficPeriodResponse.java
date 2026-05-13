package io.makewebsite.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TrafficPeriodResponse {
    private List<String> labels;
    private List<Long> visits;
    private List<Long> uniqueVisitors;
}