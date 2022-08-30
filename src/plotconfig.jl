
using GeometryBasics
using Makie

"""
    PlotConfig(<plotname>)

This struct is used as the configuration of an UnfoldMakie plot.

`<plotname>`:
- `:lines`: Line Plot
- `:butterfly`: Butterfly Plot
- `:erp`: ERP Image
- `:design`: Design Matrix Plot
- `:topo`: Topo Plot
- `:paraCoord`: Parallel Coordiante Plot

The PlotConfig includes multiple Named Tuples with settings for different areas

Their attributes can be set through setter Methods callable on the PlotConfig instance:

- `setExtraValues(kwargs...)`
- `setLayoutValues(kwargs...)`
- `setVisualValues(kwargs...)`
- `setMappingValues(kwargs...)`
- `setLegendValues(kwargs...)`
- `setColorbarValues(kwargs...)`
- `setAxisValues(kwargs...)`

# Example

`config = PlotConfig(:lines)`

`config.setLegendValues(nbanks=2)`

`config.setLayoutValues(showLegend=true, legendPosition=:bottom)`

`config.setMappingValues(color=:coefname, group=:coefname)`

"""
mutable struct PlotConfig
    plotType::Any
    extraData::NamedTuple
    layoutData::NamedTuple
    visualData::NamedTuple
    mappingData::NamedTuple
    legendData::NamedTuple
    colorbarData::NamedTuple
    axisData::NamedTuple

    setExtraValues::Function    
    setLayoutValues::Function
    setVisualValues::Function
    setMappingValues::Function
    setLegendValues::Function
    setColorbarValues::Function
    setAxisValues::Function

    # removes all varaibles from mappingData which aren't collumns in input plotData
    resolveMappings::Function

    plot::Function
    plot!::Function

    "plot types: :lineplot, :designmatrix, :topolot, :butterfly"
    function PlotConfig(pltType)
        this = new()

        this.plotType = pltType
        # standard values for ALL plots
        this.extraData = (
            # vars to make scolumns nonnumerical
            categoricalColor=true,
            categoricalGroup=true,
            topoLegend=false,
            xTicks=nothing,
            meanPlot=false,
            sortData=true,
            standardizeData=true,
            stderror=false,
            pvalue=[],
            erpBlur=10,

            # paracoord fix-values
            pc_aspect_ratio = 0.55,
            pc_right_padding = 15,
            pc_left_padding = 25,
            pc_top_padding = 26,
            pc_bottom_padding = 16,
            pc_tick_label_size = 14,
        )
        this.layoutData = (;
            showLegend=true,
            legendPosition=:right,
            showAxisLabels=true,
            border=false,
            xlabel=nothing,
            ylabel=nothing,
            ylims=nothing,
            xlims=nothing,
            useColorbar=false,
        )
        this.visualData = (;
            colormap=:haline,
        )
        this.mappingData = (
            x=:time,
            y=:estimate,
        ) 
        this.legendData = (;
            orientation = :vertical,
            tellwidth = true,
            tellheight = false
        )
        this.colorbarData = (;
            vertical = true,
            tellwidth = true,
            tellheight = false
        )

        this.axisData = (;
            xlabel = "x label",
            ylabel = "y label"
        )
        
        # setter for ANY values for Data
        """Test1"""
        this.setExtraValues = function (;kwargs...)
            this.extraData = merge(this.extraData, kwargs)
            return this
        end
        this.setLayoutValues = function (;kwargs...)
            # position affects multiple values in legendData
            kwargsVals = values(kwargs)
            if haskey(kwargsVals, :legendPosition)
                if kwargsVals.legendPosition == :right
                    sdtLegVal = (;tellwidth = true, tellheight = false, orientation = :vertical)
                    sdtBarVal = (;tellwidth = true, tellheight = false)
                elseif kwargsVals.legendPosition == :bottom
                    sdtLegVal = (;tellwidth = false, tellheight = true, orientation = :horizontal)
                    sdtBarVal = (;tellwidth = false, tellheight = true, vertical=false, flipaxis=false)
                end
                this.legendData = merge(this.legendData, sdtLegVal)
                this.colorbarData = merge(this.colorbarData, sdtBarVal)
            end

            this.layoutData = merge(this.layoutData, kwargs)
            return this
        end
        this.setVisualValues = function (;kwargs...)
            this.visualData = merge(this.visualData, kwargs)
            return this
        end
        this.setMappingValues = function (;kwargs...)
            this.mappingData = merge(this.mappingData, kwargs)
            return this
        end
        this.setLegendValues = function (;kwargs...)
            this.legendData = merge(this.legendData, kwargs)
            return this
        end
        this.setColorbarValues = function (;kwargs...)
            this.colorbarData = merge(this.colorbarData, kwargs)
            return this
        end
        this.setAxisValues = function (;kwargs...)
            this.axisData = merge(this.axisData, kwargs)
            return this
        end

        # standard values for each plotType
        if (pltType == :lineplot)
            this.setMappingValues(
                x=(:x, :time),
                y=(:y, :estimate, :yhat),
                color=(:color, :coefname),
            )
        elseif (pltType == :designmatrix)
            this.setLayoutValues(
                useColorbar = true
            )
            this.setLayoutValues(
                xlabel="",
                ylabel="",
            )
            this.setAxisValues(
                xticklabelrotation=pi/8
            )
        elseif (pltType == :topoplot || pltType == :eegtopoplot)
            this.setLayoutValues(
                border=true,
                showLegend=false,
                showAxisLabels=false,
                useColorbar = true,
            )
            this.setVisualValues(
                contours=(color=:white, linewidth=2),
                label_scatter=true,
                label_text=true,
                bounding_geometry=(pltType == :topoplot) ? Rect : Circle,
                colormap=Reverse(:RdBu),
            )
            this.setMappingValues(
                x=:xPos,
                y=:yPos,
                topodata=(:topodata, :data, :y),
                topoPositions=(:pos, :positions, :position, :topoPositions, :x, :nothing),
                topoLabels=(:labels, :label, :topoLabels, :sensor, :nothing),
                topoChannels=(:channels, :channel, :topoChannel, :nothing),
            )
        elseif (pltType == :butterfly)
            this.setExtraValues(topoLegend = true)
            this.setLayoutValues(showLegend = false)
            this.setMappingValues(
                topoPositions=(:pos, :positions, :position, :topoPositions, :x, :nothing),
                topoLabels=(:labels, :label, :topoLabels, :sensor, :nothing),
                topoChannels=(:channels, :channel, :topoChannel, :nothing),
            )
        elseif (pltType == :erp)
            this.setExtraValues(
                sortData = true,
            )
            this.setLayoutValues(
                border=false,
                showAxisLabels=true,
                useColorbar = true,
            )
        elseif (pltType == :paracoord)
            this.setExtraValues(
                sortData = true,
            )
            # this.setLegendValues(
            #     position = :rc
            # )
            this.setLayoutValues(
                xlabel = "Channels",
                ylabel = "Timestamps",
            )
            this.setMappingValues(
                channel=:channel,
                category=:category,
                time=:time,
            )
        end

        # removes all varaibles from mappingData which aren't collumns in input plotData
        this.resolveMappings = function (plotData)
            function isCollumn(col)
                string(col) ∈ names(plotData)
            end
            # filter collumns to only include the ones that are in plotData, or throw an error if none are
            function getAvailable(key, choices)
                available = choices[keys(choices)[isCollumn.(collect(choices))]]
                if length(available) >= 1
                    return available[1]
                else
                    return (:nothing ∈ collect(choices)) ?
                        nothing :
                        @error("default collumns for $key = $choices not found, user must provide one by using plotconfig.setMappingValues()")
                end
            end
            # have to use Dict here because NamedTuples break when trying to map them with keys/indices
            mappingDict = Dict()
            for (k,v) in pairs(this.mappingData)
                mappingDict[k] = isa(v, Tuple) ? getAvailable(k, v) : v
            end
            this.mappingData = (;mappingDict...)
        end

        this.plot = function (plotData::Any; kwargs...)
            this.plot!(Figure(), plotData; kwargs...)
        end

        this.plot! = function (f::Union{GridPosition, Figure}, plotData::Any; kwargs...)
            if (this.plotType == :designmatrix)
                plot_design!(f, plotData, this)
            elseif (this.plotType == :erp)
                plot_erp!(f, plotData, this)
            elseif (this.plotType == :lineplot || this.plotType == :butterfly)
                plot_line!(f, plotData, this)
            elseif (this.plotType == :paracoord)
                plot_paraCoord!(f, plotData, this; kwargs...)
            elseif (this.plotType == :topoplot || this.plotType == :eegtopoplot)
                plot_topo!(f, plotData, this; kwargs...)
            else
                @error "Unknown plot type, cannot use plot function."
            end
        end

        return this
    end
end

# filters out the entries with the given names from the tuple
function filterNamesOutTuple(inputTuple, filterNames)
    function isInName(col)
        !(col ∈ filterNames)
    end
    return inputTuple[keys(inputTuple)[isInName.(collect(keys(inputTuple)))]]
end