require 'metaruby/gui/html/button'
require 'syskit/gui/component_network_base_view'
module Syskit
    module GUI
        # Generic component network visualization
        #
        # It displays the task hierarchy as well as the dataflow network
        class ComponentNetworkView < ComponentNetworkBaseView
            attr_predicate :view_partial_plans?, true
            attr_reader :dataflow_options
            attr_reader :hierarchy_options
            attr_reader :plan
            attr_reader :task

            def initialize(page)
                super
                @view_partial_plans = true
                @plan = Roby::Plan.new

                @hierarchy_options = Hash[
                    :id => 'hierarchy',
                    :remove_compositions => false,
                    :annotations => ['task_info', 'port_details'].to_set
                ]
                @dataflow_options = Hash[
                    :id => 'dataflow',
                    :remove_compositions => false,
                    :annotations => ['task_info'].to_set,
                    :zoom => 1
                ]

                buttons = []
                buttons << MetaRuby::GUI::HTML::Button.new("dataflow/show_compositions",
                                                           :on_text => 'Show compositions',
                                                           :off_text => 'Hide compositions',
                                                           :state => !dataflow_options[:remove_compositions])
                buttons << MetaRuby::GUI::HTML::Button.new("dataflow/zoom",
                                                           :on_text => "Zoom +",
                                                           :off_text => "Zoom +",
                                                           :state => true)
                buttons << MetaRuby::GUI::HTML::Button.new("dataflow/unzoom",
                                                           :on_text => "Zoom -",
                                                           :off_text => "Zoom -",
                                                           :state => true)
                buttons << MetaRuby::GUI::HTML::Button.new("dataflow/save",
                                                           :on_text => "Save svg",
                                                           :off_text => "Save svg",
                                                           :state => true)
                Syskit::Graphviz.available_annotations.sort.each do |ann_name|
                    buttons << MetaRuby::GUI::HTML::Button.new("annotations/#{ann_name}",
                                                :on_text => "Show #{ann_name}",
                                                :off_text => "Hide #{ann_name}",
                                                :state => dataflow_options[:annotations].include?(ann_name))
                end
                dataflow_options[:buttons] = buttons
                buttons = []
                buttons << MetaRuby::GUI::HTML::Button.new("hierarchy/save",
                                                           :on_text => "Save svg",
                                                           :off_text => "Save svg",
                                                           :state => true)
                hierarchy_options[:buttons] = buttons
            end

            def enable
                connect(page, SIGNAL('buttonClicked(const QString&,bool)'), self, SLOT('buttonClicked(const QString&,bool)'))
            end

            def disable
                disconnect(page, SIGNAL('buttonClicked(const QString&,bool)'), self, SLOT('buttonClicked(const QString&,bool)'))
            end

            def render(model, render_options = Hash.new)
                super

                plan.clear
                options = Kernel.validate_options options, :method => :instanciate_model
                @task = begin send(options[:method], model, plan)
                        rescue Exception => e
                            if view_partial_plans? then
                                Roby.app.register_exception(e)
                                nil
                            else raise
                            end
                        end
                render_plan(render_options)
            end

            def render_plan(options = Hash.new)
                options = Kernel.validate_options options, :interactive => true

                hierarchy_options = self.hierarchy_options.dup
                dataflow_options = self.dataflow_options.dup
                if !options[:interactive]
                    hierarchy_options.delete(:buttons)
                    dataflow_options.delete(:buttons)
                    Syskit::Graphviz.available_annotations.sort.each do |ann_name|
                        dataflow_options[:annotations] << ann_name
                    end
                end

                page.push_plan('Task Dependency Hierarchy', 'hierarchy', plan, hierarchy_options)
                page.push_plan('Dataflow', 'dataflow', plan, dataflow_options)
                emit updated
            end

            def save_svg title
                page.fragments.each do |f|
                    if f.title == title
                        file_name = Qt::FileDialog::getSaveFileName @parent, 
                            "Save #{title} as SVG", ".", "SVG (*.svg)"
                        if file_name
                            File.open(file_name,"w") do |file|
                                file.write f.html
                            end
                        end
                    end
                end
            end

            def buttonClicked(button_id, new_state)
                case button_id
                when /\/dataflow\/show_compositions/
                    dataflow_options[:remove_compositions] = !new_state
                when /\/dataflow\/zoom/
                    dataflow_options[:zoom] += 0.1
                when /\/dataflow\/unzoom/
                    if dataflow_options[:zoom] > 0.1
                        dataflow_options[:zoom] -= 0.1
                    end
                    dataflow_options[:remove_compositions] = !new_state
                when /\/dataflow\/save/
                    save_svg "Dataflow"
                when /\/hierarchy\/save/
                    save_svg "Task Dependency Hierarchy"
                when  /\/annotations\/(\w+)/
                    ann_name = $1
                    if new_state then dataflow_options[:annotations] << ann_name
                    else dataflow_options[:annotations].delete(ann_name)
                    end
                end
                page.push_plan('Dataflow', 'dataflow', plan, dataflow_options)
                emit updated
            end
            slots 'buttonClicked(const QString&,bool)'
        end
    end
end

